import copy
import hashlib
import json
from pathlib import Path
import struct
import sys
import unittest
from unittest.mock import patch
import uuid
import zlib
from types import SimpleNamespace

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from lab import ROOT, RUNS, CHATDEV, prepare_workspace, write_json
from lab_android import AndroidExperiment, Manager
from vision import capture, png_metadata, provider_images, validate_observation
from bridge import codex_command


def png():
    def chunk(kind, data):
        return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data))
    return (b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", 1, 1, 8, 2, 0, 0, 0))
            + chunk(b"IDAT", zlib.compress(b"\x00\x22\x44\x66")) + chunk(b"IEND", b""))


class VisionTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        sys.path.insert(0, str(CHATDEV))

    def fixture(self):
        from tests.test_android import OfflineManager, add_flutter
        run = RUNS / ("vision_offline_" + uuid.uuid4().hex[:8])
        run.mkdir(parents=True)
        write_json(run / "manifest.json", {"run_id": run.name})
        workspace, _, _ = prepare_workspace(run)
        add_flutter(workspace)
        client = OfflineManager()
        experiment = AndroidExperiment(run, client=client)
        cycle = run / "cycles/001"
        cycle.mkdir(parents=True)
        android = experiment.after_cycle(cycle, {"name_status": []})
        return run, cycle, experiment, android

    def test_capture_png_identity_and_corruption_without_other_app_pixels(self):
        run, cycle, experiment, android = self.fixture()
        result = capture(experiment, cycle, android)
        self.assertEqual(result["status"], "captured")
        self.assertEqual((cycle / "visual/screen.png").read_bytes(), png())
        self.assertTrue(result["offline"])
        for data in (png()[:-1], b"not png", png()[:40] + b"wrong" + png()[45:]):
            with self.assertRaises(ValueError):
                png_metadata(data)
        cycle = run / "cycles/002"; cycle.mkdir()
        definition = experiment.state["session"]
        experiment.client.capture = lambda _: ({**definition, **png_metadata(png()), "serial": "emulator-5554"}, png())
        result = capture(experiment, cycle, android)
        self.assertEqual(result["status"], "capture_failed")
        self.assertFalse((cycle / "visual/screen.png").exists())
        self.assertEqual(json.loads((cycle / "visual/evaluation.json").read_text())["status"], "not_observed")

    def test_capture_failure_or_not_ready_never_claims_an_observation(self):
        run, cycle, experiment, android = self.fixture()
        with patch.object(experiment.client, "capture", side_effect=RuntimeError("Foreground belongs to another package")):
            result = capture(experiment, cycle, android)
        self.assertEqual(result["status"], "capture_failed")
        self.assertIn("Foreground", result["error"])
        self.assertFalse((cycle / "visual/screen.png").exists())
        with patch.object(experiment.client, "capture") as call:
            result = capture(experiment, cycle, {"status": "validation_failed"})
        call.assert_not_called()
        self.assertEqual(result["status"], "unavailable")

    def messages(self):
        sys.path.insert(0, str(CHATDEV))
        from entity.messages import AttachmentRef, Message, MessageRole, MessageBlock, MessageBlockType
        run, cycle, experiment, android = self.fixture()
        visual = capture(experiment, cycle, android)
        artifacts = run / "decisions/001"
        target = artifacts / "chatdev/attachments/screen.png"
        target.parent.mkdir(parents=True)
        target.write_bytes(png())
        write_json(artifacts / "visual-input.json", visual)
        image = MessageBlock(type=MessageBlockType.IMAGE, attachment=AttachmentRef(
            attachment_id="test", local_path=str(target), mime_type="image/png", sha256=visual["image_id"]))
        conversation = [Message(role=MessageRole.USER, content=[MessageBlock.text_block("Review the supplied screenshot"), image])]
        return artifacts, target, visual, conversation

    def decision(self, visual):
        return {"action": "execute", "assessment": "needs_revision", "summary": "Offline protocol fixture",
                "instruction": "Improve the visible layout", "visual": {"image_id": visual["image_id"], "observed": True,
                "observations": "Fixture only: protocol test", "visible_text": [], "next_change_reason": "Fixture only"}}

    def test_native_image_blocks_are_attached_as_binary_cli_input(self):
        artifacts, target, visual, conversation = self.messages()
        images, expected = provider_images(conversation, artifacts)
        self.assertEqual(images, [target])
        command = codex_command({"executor": "fake", "fake_mode": "success"}, artifacts.parent.parent / "workspace",
                                artifacts / "final", sandbox="read-only", images=images)
        self.assertEqual(command[command.index("--image")+1], str(target))
        self.assertEqual(command[-1], "-")
        self.assertEqual(expected["image_id"], visual["image_id"])

    def test_missing_stale_or_external_sdk_image_is_rejected(self):
        artifacts, target, visual, conversation = self.messages()
        with self.assertRaisesRegex(ValueError, "exactly"):
            provider_images([], artifacts)
        conversation[0].content[1].attachment.sha256 = "stale"
        with self.assertRaisesRegex(ValueError, "match"):
            provider_images(conversation, artifacts)
        conversation[0].content[1].attachment.local_path = str(ROOT.parent / "apps/quizai/pubspec.yaml")
        with self.assertRaisesRegex(ValueError, "inside"):
            provider_images(conversation, artifacts)

    def test_multimodal_reception_errors_are_persisted_without_text_fallback(self):
        from planner_provider import CodexPlanner
        artifacts, target, visual, conversation = self.messages()
        config = SimpleNamespace(base_url=None, api_key=None, name="default", provider="lab_codex", params={
            "artifacts_dir": str(artifacts), "workspace": str(artifacts.parent.parent/"workspace"), "executable": "codex", "timeout": 10})
        provider = CodexPlanner(config)
        decision = self.decision(visual)
        with patch("planner_provider.invoke_codex", return_value={"status": "completed", "message": json.dumps(decision)}) as invoke:
            provider.call_model(provider, conversation, [])
        self.assertEqual(invoke.call_args.kwargs["images"], [target])
        self.assertEqual(json.loads((artifacts/"visual-reception.json").read_text())["status"], "model_reported_observed")
        for answer in ({"status": "failed", "message": "unsupported image"},
                       {"status": "completed", "message": json.dumps({k:v for k,v in decision.items() if k != "visual"})},
                       {"status": "completed", "message": json.dumps({**decision, "visual": {**decision["visual"], "observed": False}})}):
            with patch("planner_provider.invoke_codex", return_value=answer):
                with self.assertRaises(Exception):
                    provider.call_model(provider, conversation, [])
            self.assertEqual(json.loads((artifacts/"visual-reception.json").read_text())["status"], "reception_failed")
        bad = copy.deepcopy(decision); bad["visual"]["image_id"] = "previous cycle"
        with self.assertRaises(ValueError):
            validate_observation(bad, visual)

    def test_running_owner_changed_during_capture_rejects_image(self):
        run, cycle, experiment, android = self.fixture()
        client = experiment.client
        client.offline = False
        current = client.sessions[-1]
        current.update(appPid="123", epoch="worker:123")
        definition = experiment.state["session"]
        def changed(_):
            current["epoch"] = "other:124"
            return {**definition, **png_metadata(png()), "appPid": "123", "epoch": "worker:123"}, png()
        client.capture = changed
        result = capture(experiment, cycle, android)
        self.assertEqual(result["status"], "capture_failed")
        self.assertFalse((cycle/"visual/screen.png").exists())

"""Offline regression tests for the single creative coding agent."""
import sys
import tempfile
import unittest
from hashlib import sha256
from pathlib import Path
from unittest.mock import patch
from zipfile import ZipFile

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import creative


class CreativeLoopTest(unittest.TestCase):
    def test_zip_preserves_original_image_and_full_text(self):
        with tempfile.TemporaryDirectory() as folder:
            archive = Path(folder) / "seed.zip"
            image = b"\x89PNG\r\n\x1a\nCONTENTS"
            text = "# Manifest\nUn texto sin transformaciones."
            with ZipFile(archive, "w") as file:
                file.writestr("imagen.png", image)
                file.writestr("texto.md", text)
            result = creative.read_zip(archive)
            self.assertEqual(result, (image, text))

    def test_source_detection_ignores_flutter_generated_files(self):
        with tempfile.TemporaryDirectory() as folder:
            workspace = Path(folder)
            (workspace / "lib").mkdir()
            (workspace / ".dart_tool").mkdir()
            (workspace / "lib/main.dart").write_text("void main() {}")
            before = creative.snapshot(workspace)
            (workspace / ".dart_tool/build").write_text("cache")
            (workspace / "lib/engine.dart").write_text("class Engine {}")
            after = creative.snapshot(workspace)
            self.assertEqual(creative.changed(before, after), ["lib/engine.dart"])

    def test_iterations_keep_original_brief_and_real_work_context(self):
        state = {"idea": "# SpinAI\nEl usuario crea.", "feedback": "",
                 "cycles": [{"number": 1, "message": "Motor físico iniciado",
                             "changed": ["lib/engine.dart"], "diagnostic": "Flutter ok"}]}
        prompt = creative.build_prompt(state)
        self.assertIn("# SpinAI", prompt)
        self.assertIn("Motor físico iniciado", prompt)
        self.assertIn("Flutter ok", prompt)
        self.assertIn("Escribe y modifica código", prompt)

    def test_agent_receives_original_image_and_can_modify_multiple_files(self):
        with tempfile.TemporaryDirectory() as folder:
            room = Path(folder)
            workspace = room / "workspace"
            (workspace / "lib").mkdir(parents=True)
            data = b"original binary image"
            (room / "seed.png").write_bytes(data)
            state = {"idea": "Motor de giro", "cycles": [], "model": None,
                     "feedback": "", "seed_image": {"file": "seed.png", "sha256": sha256(data).hexdigest()}}
            def code_change(request, workspace, artifacts, prompt, **kwargs):
                self.assertEqual(request["network"], True)
                self.assertEqual(kwargs["images"], [room / "seed.png"])
                (workspace / "lib" / "engine.dart").write_text("class Engine {}")
                (workspace / "pubspec.yaml").write_text("dependencies: {}")
                return {"status": "completed", "message": "Dos archivos escritos"}
            with patch.object(creative, "invoke_codex", side_effect=code_change), \
                 patch.object(creative, "validate", return_value="pub get ok"):
                result = creative.cycle(room, state, 1, "codex", 900)
            self.assertEqual(result["changed"], ["lib/engine.dart", "pubspec.yaml"])
            self.assertEqual(len(state["cycles"]), 1)


if __name__ == "__main__":
    unittest.main()

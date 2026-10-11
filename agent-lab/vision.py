"""Real Android capture receipts and validated ChatDev image attachments."""

import hashlib
import json
from pathlib import Path
import struct
import zlib

from lab import ROOT, utc_now, write_json
from lab_android import contained


def png_metadata(data):
    """Validate complete screenshot bytes without invoking SDKs or models."""
    if len(data) > 16 * 1024 * 1024 or not data.startswith(b"\x89PNG\r\n\x1a\n"):
        raise ValueError("Capture is not a bounded PNG")
    offset, width, height, compressed, ended = 8, 0, 0, bytearray(), False
    while offset < len(data):
        if offset + 12 > len(data):
            raise ValueError("Truncated PNG chunk")
        size = struct.unpack_from(">I", data, offset)[0]
        end = offset + 12 + size
        if end > len(data):
            raise ValueError("Truncated PNG payload")
        kind, payload = data[offset+4:offset+8], data[offset+8:end-4]
        if zlib.crc32(kind + payload) != struct.unpack_from(">I", data, end-4)[0]:
            raise ValueError("Corrupt PNG checksum")
        if offset == 8:
            if kind != b"IHDR" or size != 13:
                raise ValueError("PNG has no image header")
            width, height = struct.unpack_from(">II", payload)
            if not 1 <= width <= 4096 or not 1 <= height <= 4096 or payload[12] != 0:
                raise ValueError("Unsupported PNG dimensions or interlace")
            depth, color = payload[8], payload[9]
            channels = {0: 1, 2: 3, 3: 1, 4: 2, 6: 4}.get(color)
            if depth not in (1, 2, 4, 8, 16) or not channels or payload[10:12] != b"\x00\x00":
                raise ValueError("Unsupported PNG format")
        if kind == b"IDAT":
            compressed.extend(payload)
        if kind == b"IEND":
            if size or end != len(data):
                raise ValueError("Invalid PNG ending")
            ended = True
        offset = end
    if not ended or not compressed:
        raise ValueError("Incomplete PNG")
    row_bytes = (width * channels * depth + 7) // 8 + 1
    expected_size = height * row_bytes
    decoder = zlib.decompressobj()
    decoded = decoder.decompress(compressed, expected_size + 1)
    if not decoder.eof or decoder.unused_data or len(decoded) != expected_size:
        raise ValueError("Invalid PNG pixel data")
    if any(decoded[index] > 4 for index in range(0, len(decoded), row_bytes)):
        raise ValueError("Invalid PNG filter")
    return {"sha256": hashlib.sha256(data).hexdigest(), "width": width, "height": height, "bytes": len(data)}


def capture(experiment, cycle, android):
    """Only persist pixels after shared manager and experiment ownership checks."""
    folder = contained(cycle / "visual", experiment.run_dir)
    folder.mkdir(exist_ok=True)
    result = {"status": "unavailable", "at": utc_now(), "iteration": cycle.name,
              "offline": bool(getattr(experiment.client, "offline", False))}
    try:
        if android.get("status") != "running" or not android.get("validation", {}).get("passed"):
            result["reason"] = "Flutter validation or running state not confirmed"
            return result
        definition = experiment.state["session"]
        current = experiment.owned(experiment.client.call("List"))
        if not current or not current.get("active") or current.get("status") != "running":
            raise RuntimeError("Experiment session is not running")
        receipt, data = experiment.client.capture(definition)
        for field in ("appId", "serial", "packageName", "avdName"):
            if receipt.get(field) != definition[field]:
                raise ValueError("Capture identity does not match the experiment")
        if not result["offline"]:
            if not receipt.get("appPid") or receipt.get("appPid") != current.get("appPid") or receipt.get("epoch") != current.get("epoch"):
                raise ValueError("Capture runtime does not match the running experiment")
            after = experiment.owned(experiment.client.call("List"))
            if not after or not after.get("active") or after.get("epoch") != current.get("epoch"):
                raise ValueError("Experiment changed during capture")
        metadata = png_metadata(data)
        if any(receipt.get(field) != metadata[field] for field in ("sha256", "width", "height")):
            raise ValueError("Capture bytes do not match the manager receipt")
        target = folder / "screen.png"
        with target.open("xb") as image:
            image.write(data)
        result.update({"status": "captured", "image_id": metadata["sha256"], **metadata,
                       "image": target.relative_to(experiment.run_dir).as_posix(), "capture": receipt})
    except Exception as exc:
        result.update(status="capture_failed", error_type=type(exc).__name__, error=str(exc))
    finally:
        write_json(folder / "capture.json", result)
        if result["status"] != "captured":
            write_json(folder / "evaluation.json", {"status": "not_observed", "capture": result})
    return result


def attachment_path(run_dir, visual):
    path = contained(run_dir / visual["image"], run_dir)
    metadata = png_metadata(path.read_bytes())
    if metadata["sha256"] != visual["image_id"]:
        raise ValueError("Screenshot changed before deliberation")
    return path


def provider_images(conversation, artifacts):
    """Verify the SDK's actual IMAGE blocks against controller-owned metadata."""
    from entity.messages import MessageBlockType
    expected_file = artifacts / "visual-input.json"
    expected = json.loads(expected_file.read_text(encoding="utf-8")) if expected_file.exists() else None
    images = []
    for message in conversation:
        for block in message.blocks():
            if block.type is MessageBlockType.TEXT:
                continue
            if block.type is not MessageBlockType.IMAGE or not block.attachment or not block.attachment.local_path:
                raise ValueError("Unsupported or missing multimodal attachment")
            if not expected:
                raise ValueError("Unexpected image outside the current visual evaluation")
            path = contained(Path(block.attachment.local_path), artifacts / "chatdev")
            metadata = png_metadata(path.read_bytes())
            if metadata["sha256"] != expected["image_id"] or block.attachment.sha256 != metadata["sha256"]:
                raise ValueError("SDK attachment does not match the current screenshot")
            images.append(path)
    if bool(expected) != bool(images) or len(images) > 1:
        raise ValueError("ChatDev did not deliver exactly the current screenshot")
    return images, expected


def validate_observation(decision, expected):
    import jsonschema
    schema = json.loads((ROOT / "prompts/visual-decision.schema.json").read_text(encoding="utf-8"))
    jsonschema.validate(decision, schema)
    observation = decision["visual"]
    if observation["image_id"] != expected["image_id"] or observation["observed"] is not True:
        raise ValueError("Model did not report observing the current screenshot")
    if not observation["observations"].strip() or not observation["next_change_reason"].strip():
        raise ValueError("Model returned an empty visual evaluation")
    return observation

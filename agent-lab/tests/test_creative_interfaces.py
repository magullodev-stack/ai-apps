"""Offline contracts for creative agents' native tool paths and model format."""
import json
import sys
from zipfile import ZipFile
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import shared_ai
import creative
from creative_tools import studio_tools


class CreativeInterfacesTest(unittest.TestCase):
    def test_readable_paths_match_listed_paths(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            (root / "workspace" / "lib").mkdir(parents=True)
            (root / "workspace" / "lib" / "main.dart").write_text("void main() {}")
            with patch.object(studio_tools, "_room", return_value=root), \
                 patch.object(studio_tools, "_announce", side_effect=lambda _, value: value):
                self.assertEqual(studio_tools._path("."), root / "workspace")
                self.assertEqual(studio_tools._path("main.dart"),
                                 root / "workspace" / "lib" / "main.dart")
                self.assertEqual(studio_tools._path("lib/main.dart"),
                                 root / "workspace" / "lib" / "main.dart")
                self.assertEqual(studio_tools._path("main.dart", writable=True),
                                 root / "workspace" / "lib" / "main.dart")
                self.assertIn("lib/main.dart", studio_tools.room_list("lib"))
                self.assertIn("lib/", studio_tools.room_list("."))
                self.assertEqual(studio_tools.room_read("main.dart"), "void main() {}")
                for name in ("../secret.dart", "/etc/passwd", "C:/secret.dart"):
                    with self.subTest(name=name), self.assertRaises(ValueError):
                        studio_tools._path(name, writable=True)

    def test_bad_model_format_does_not_fake_a_tool_or_abort_round(self):
        usage = {"inputTokens": 51, "outputTokens": 7}
        with patch.object(shared_ai, "_request", return_value={"text": "{invalid", "usage": usage}):
            result, returned_usage = shared_ai.generate_action("gpt-5.6-luna", "explora")
        self.assertEqual(result["tool"], "none")
        self.assertIn("Error de formato", result["speech"])
        self.assertEqual(returned_usage, usage)

    def test_seed_archive_keeps_binary_and_text_distinct(self):
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / "seed.zip"
            with ZipFile(path, "w") as z:
                z.writestr("imagen.png", b"\x89PNG\r\n\x1a\nDATA")
                z.writestr("texto.md", "# Texto propio")
            image, text = creative.read_seed_zip(path)
        self.assertEqual(image, b"\x89PNG\r\n\x1a\nDATA")
        self.assertEqual(text, "# Texto propio")

    def test_service_receives_original_image_field(self):
        action = {"speech": "Veo la referencia", "tool": "none", "path": "", "content": ""}
        reference = {"mimeType": "image/png", "data": "AAECAw=="}
        with patch.object(shared_ai, "_request",
                          return_value={"text": json.dumps(action), "usage": {}}) as request:
            result, _ = shared_ai.generate_action("gpt-5.6-luna", "mi texto", image=reference)
        self.assertEqual(result, action)
        transmitted = json.loads(request.call_args.kwargs["data"])
        self.assertEqual(transmitted["input"], "mi texto")
        self.assertEqual(transmitted["image"], reference)

    def test_valid_model_action_is_not_changed(self):
        action = {"speech": "Voy a explorar", "tool": "room_list", "path": ".", "content": ""}
        with patch.object(shared_ai, "_request", return_value={"text": json.dumps(action), "usage": {}}):
            actual, _ = shared_ai.generate_action("gpt-5.6-luna", "explora")
        self.assertEqual(actual, action)


if __name__ == "__main__":
    unittest.main()

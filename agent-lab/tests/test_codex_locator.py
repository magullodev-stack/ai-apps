"""Offline contracts for locating Codex in the installed VS Code extension."""
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import codex_locator


class CodexLocatorTests(unittest.TestCase):
    def test_vscode_bundled_cli_is_found_without_path_entry(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            binary = root / "openai.chatgpt-1.2.3" / "bin" / "windows-x86_64" / "codex.exe"
            binary.parent.mkdir(parents=True)
            binary.write_bytes(b"dummy binary")
            with patch.object(codex_locator.shutil, "which", return_value=None), \
                 patch.object(codex_locator.platform, "machine", return_value="AMD64"):
                self.assertEqual(codex_locator.find_codex(roots=[root]), str(binary.resolve()))

    def test_absent_cli_does_not_guess_a_path(self):
        with tempfile.TemporaryDirectory() as temp:
            with patch.object(codex_locator.shutil, "which", return_value=None):
                self.assertIsNone(codex_locator.find_codex(roots=[temp]))

    def test_explicit_cli_path_takes_priority(self):
        with tempfile.TemporaryDirectory() as temp:
            file = Path(temp) / "codex.exe"
            file.write_bytes(b"dummy binary")
            self.assertEqual(codex_locator.find_codex(str(file)), str(file.resolve()))

    def test_does_not_resolve_arbitrary_names_into_vscode_binary(self):
        with tempfile.TemporaryDirectory() as temp:
            with patch.object(codex_locator.shutil, "which", return_value=None):
                self.assertIsNone(codex_locator.find_codex("something-else", roots=[temp]))


if __name__ == "__main__":
    unittest.main()

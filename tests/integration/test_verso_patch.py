"""Small patch safety fixtures: no real dependency/cache modifications."""
import hashlib
import importlib.util
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

SCRIPT = Path(__file__).resolve().parents[2] / "scripts/apply-verso-patches.py"
spec = importlib.util.spec_from_file_location("verso_patch", SCRIPT)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class PatchTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix="verso-patch-test.")
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.target = self.root / module.TARGET
        self.target.parent.mkdir(parents=True)
        self.target.write_text("before\n")
        diff = self.root / "fixture.patch"
        diff.write_text("--- a/" + str(module.TARGET) + "\n+++ b/" + str(module.TARGET) +
                        "\n@@ -1 +1 @@\n-before\n+after\n")
        for key, value in (("PATCH", diff), ("BEFORE", hashlib.sha256(b"before\n").hexdigest()),
                           ("AFTER", hashlib.sha256(b"after\n").hexdigest())):
            self.enterContext(patch.object(module, key, value))

    def test_check_apply_and_idempotence(self):
        self.assertEqual(module.apply(self.root, check=True), "patchable")
        self.assertEqual(self.target.read_text(), "before\n")
        self.assertEqual(module.apply(self.root), "patched")
        self.assertEqual(module.apply(self.root), "already patched")
        self.assertEqual(self.target.read_text(), "after\n")

    def test_unknown_source_preserved(self):
        self.target.write_text("user edit\n")
        with self.assertRaisesRegex(ValueError, "Unknown Verso"):
            module.apply(self.root)
        self.assertEqual(self.target.read_text(), "user edit\n")

    def test_missing_and_symlink_rejected(self):
        self.target.unlink()
        with self.assertRaisesRegex(ValueError, "Missing regular"):
            module.apply(self.root)
        other = self.root / "other"
        other.write_text("before\n")
        self.target.symlink_to(other)
        with self.assertRaisesRegex(ValueError, "Missing regular"):
            module.apply(self.root)
        self.assertEqual(other.read_text(), "before\n")


if __name__ == "__main__":
    unittest.main()

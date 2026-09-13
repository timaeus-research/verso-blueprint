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
        self.spec = (module.TARGET, hashlib.sha256(b"before\n").hexdigest(),
                     hashlib.sha256(b"after\n").hexdigest(), diff)
        self.enterContext(patch.object(module, "PATCHES", (self.spec,)))

    def add_second(self, contents="before\n"):
        relative = Path("second.lean")
        target = self.root / relative
        target.write_text(contents)
        diff = self.root / "second.patch"
        diff.write_text("--- a/second.lean\n+++ b/second.lean\n@@ -1 +1 @@\n-before\n+after\n")
        self.enterContext(patch.object(module, "PATCHES", (self.spec,
            (relative, self.spec[1], self.spec[2], diff))))
        return target, diff

    def test_all_targets_validated_before_any_write(self):
        target, _ = self.add_second("user edit\n")
        with self.assertRaisesRegex(ValueError, "Unknown Verso"):
            module.apply(self.root)
        self.assertEqual(self.target.read_text(), "before\n")
        self.assertEqual(target.read_text(), "user edit\n")

    def test_all_patches_checked_before_any_write(self):
        target, diff = self.add_second()
        diff.write_text(diff.read_text().replace("-before", "-mismatch"))
        with self.assertRaises(module.subprocess.CalledProcessError):
            module.apply(self.root)
        self.assertEqual(self.target.read_text(), "before\n")
        self.assertEqual(target.read_text(), "before\n")

    def test_mixed_state_and_idempotence(self):
        target, _ = self.add_second("after\n")
        self.assertEqual(module.apply(self.root, check=True), "patchable")
        self.assertEqual(module.apply(self.root), "patched")
        self.assertEqual(module.apply(self.root), "already patched")
        self.assertEqual(target.read_text(), "after\n")

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

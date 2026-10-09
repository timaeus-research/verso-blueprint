"""Check native theorem proof folding without hiding internal statement proofs.

Run with: uv run --no-project --with playwright python
  tests/integration/check_proof_folding.py
"""
from pathlib import Path
import subprocess
import tempfile

from playwright.sync_api import sync_playwright

PACKAGE_ROOT = Path(__file__).resolve().parents[2]


def main():
    with tempfile.TemporaryDirectory(prefix="blueprint-proof-folding.") as tmp:
        output = Path(tmp) / "site"
        subprocess.run([
            "./scripts/lean-low-priority", "lake", "lean", "tests/ProofFoldingMain.lean",
            "--", "--run", "tests/ProofFoldingMain.lean", "--output", str(output),
        ], cwd=PACKAGE_ROOT, check=True)
        with sync_playwright() as playwright:
            browser = playwright.chromium.launch()
            page = browser.new_page()
            page.goto((output / "html-multi/index.html").as_uri())
            block = page.locator("details.bp_code_block code.hl.lean.block")
            block.wait_for()
            page.wait_for_function("document.querySelector('code.hl.lean.block').dataset.bpProofHider === '1'")
            assert block.locator(".bp-proof-by-toggle").count() == 4
            tails = block.locator(".bp-proof-tail").all_text_contents()
            assert len(tails) == 4
            assert all("theorem" not in tail for tail in tails), tails
            assert "exact ⟨rfl, trivial⟩" in tails[0], tails
            assert "have h : True := by trivial" in tails[2], tails
            visible = block.evaluate("""node => {
              const copy = node.cloneNode(true);
              copy.querySelectorAll('.bp-proof-tail, .tactic-state').forEach(n => n.remove());
              return copy.textContent;
            }""")
            assert "(⟨0, by decide⟩ : Fin 1).val = 0 ∧ True := by" in visible, visible
            assert "n = n := by" in visible, visible
            assert "(⟨0, by decide⟩ : Fin 1).val = 0 := rfl" in visible, visible
            assert "theorem termBodyWithNestedProof : True := (by trivial)" in visible, visible
            assert "def visibleDefinition : Nat := by exact 7" in visible, visible
            assert "(let n : Nat := (by exact 0); n = n) := by" in visible, visible
            assert "let n : Nat := 0; n = n := by" in visible, visible
            toggle = block.locator(".bp-proof-by-toggle").first
            # The outer code panel is independent of the inner proof toggle.
            block.evaluate("node => node.closest('details').open = true")
            toggle.click()
            assert toggle.get_attribute("aria-expanded") == "true"
            assert "bp-proof-tail-hidden" not in block.locator(".bp-proof-tail").first.get_attribute("class")
            toggle.press("Enter")
            assert toggle.get_attribute("aria-expanded") == "false"
            assert "bp-proof-tail-hidden" in block.locator(".bp-proof-tail").first.get_attribute("class")
            browser.close()
        print("Native proof folding: internal arguments and complete statements preserved; outer proofs toggle.")


if __name__ == "__main__":
    main()

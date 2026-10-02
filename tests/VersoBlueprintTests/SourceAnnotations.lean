/-
Copyright (c) 2026 Timaeus. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
-/

import VersoBlueprintTests.Blueprint.Support

/-!
Annotation boxes taken from the "Relation to the source." section of the docstrings of the
declarations a node embeds, with review badges from the review ledger.
-/

namespace Verso.VersoBlueprintTests.SourceAnnotations

open Lean Verso Genre Manual Informal
open Verso.VersoBlueprintTests.Blueprint.Support

private def impls : ExtensionImpls := extension_impls%

/-! ## The item hash: 64-bit FNV-1a over the whitespace-normalized text -/

/-- info: true -/
#guard_msgs in
#eval
  -- the published FNV-1a 64 test vectors
  SourceRelation.hex16 (SourceRelation.fnv1a64 "".toUTF8) == "cbf29ce484222325" &&
  SourceRelation.hex16 (SourceRelation.fnv1a64 "a".toUTF8) == "af63dc4c8601ec8c" &&
  SourceRelation.hex16 (SourceRelation.fnv1a64 "foobar".toUTF8) == "85944171f73967e8" &&
  SourceRelation.normalizeWhitespace "  a \t b\n\n  c \r\n" == "a b c" &&
  SourceRelation.normalizeWhitespace "x y" == "x y" &&
  SourceRelation.itemHash "foobar" == "85944171f73967e8" &&
  SourceRelation.itemHash "  `f x` is\n  the paper's $f(x)$. " ==
    SourceRelation.itemHash "`f x` is the paper's $f(x)$." &&
  SourceRelation.itemHash "`f x` is the paper's $f(x)$." != SourceRelation.itemHash "`f x` is the paper's $f(y)$."

-- Reference values for other implementations (the same function in Python gives these).
/-- info: true -/
#guard_msgs in
#eval
  SourceRelation.itemHash "`S.boundarySeq E₀ i` is his $E_i$." == "d78b9d85c3d102a0" &&
  SourceRelation.itemHash "  `S.boundarySeq E₀ i`\n   is his $E_i$.  " == "d78b9d85c3d102a0" &&
  SourceRelation.itemHash "`srcSucc n` is the paper's $n + 1$, written\n  $\\operatorname{succ}(n)$ there." ==
    "c08cdc66cd302f9d"

/-! ## Parsing -/

private def sampleDoc : String := "The successor of `n`.

Relation to the source.
* **Translation.** `srcSucc n` is the paper's $n + 1$, written
  $\\operatorname{succ}(n)$ there.

* **Formalisation note.** The paper works with *positive* integers;
  here `n : Nat` may be zero.

  A second paragraph.
* A bullet without a label.
* **Gap.** An unknown label.

Proof. By definition."

/-- info: true -/
#guard_msgs in
#eval
  let p := SourceRelation.parse sampleDoc
  p.items.map (·.label) == #[.translation, .formalisationNote] &&
  p.items[0]!.markdown == "`srcSucc n` is the paper's $n + 1$, written\n$\\operatorname{succ}(n)$ there." &&
  p.items[1]!.markdown ==
    "The paper works with *positive* integers;\nhere `n : Nat` may be zero.\n\nA second paragraph." &&
  p.problems == #[.unlabelled "A bullet without a label.",
    .unknownLabel "Gap." "**Gap.** An unknown label."] &&
  p.remainder == "The successor of `n`.\n\nRelation to the source.\n* A bullet without a label.\n" ++
    "* **Gap.** An unknown label.\n\nProof. By definition." &&
  SourceRelation.stripSection "No section here.\n\nProof. Trivial." == "No section here.\n\nProof. Trivial." &&
  SourceRelation.stripSection "Text.\n\nRelation to the source.\n* **Correction.** A hypothesis.\n" ==
    "Text." &&
  (SourceRelation.parse "Text.\n\nRelation to the source.\nNo list here.").problems == #[.noItems] &&
  -- the period belongs inside the bold label
  (SourceRelation.parse "Relation to the source.\n* **Translation**. x").problems ==
    #[.unknownLabel "Translation" "**Translation**. x"]

/-! ## The ledger -/

/-- info: true -/
#guard_msgs in
#eval
  let entries : Array ReviewLedger.Entry := #[
    { decl := "A.b", kind := "Translation", hash := "0123456789abcdef", reviewer := "BS", date := "2026-10-01" },
    { decl := "A.b", kind := "Translation", hash := "0123456789abcdef", reviewer := "AS", date := "2026-10-02" },
    { decl := "A.b", kind := "Correction", hash := "1111111111111111", reviewer := "BS", date := "2026-10-01" }]
  ReviewLedger.status entries "A.b" "Translation" "0123456789abcdef" == .reviewed "AS" "2026-10-02" &&
  ReviewLedger.status entries "A.b" "Correction" "0123456789abcdef" == .changedSinceReview &&
  ReviewLedger.status entries "A.b" "Interpretation" "0123456789abcdef" == .unreviewed &&
  ReviewLedger.status entries "A.c" "Translation" "0123456789abcdef" == .unreviewed &&
  (ReviewLedger.parseLedger "[]").1.isEmpty &&
  (ReviewLedger.parseLedger "{}").2 == #["expected a JSON array of entries"] &&
  (ReviewLedger.parseLedger
    "[{\"decl\":\"A.b\",\"kind\":\"Gap\",\"hash\":\"0123456789abcdef\",\"reviewer\":\"BS\",\"date\":\"2026-10-01\"},
      {\"decl\":\"A.b\",\"kind\":\"Translation\",\"hash\":\"0123456789ABCDEF\",\"reviewer\":\"BS\",\"date\":\"2026-10-01\"},
      {\"decl\":\"A.b\",\"kind\":\"Translation\",\"hash\":\"0123456789abcdef\",\"reviewer\":\"BS\",\"date\":\"1 Oct\"},
      {\"decl\":\"A.b\",\"kind\":\"Translation\",\"hash\":\"0123456789abcdef\",\"reviewer\":\"BS\",\"date\":\"2026-10-01\"}]").1.size == 1 &&
  (ReviewLedger.parseLedger
    "[{\"decl\":\"A.b\",\"kind\":\"Gap\",\"hash\":\"0123456789abcdef\",\"reviewer\":\"BS\",\"date\":\"2026-10-01\"}]").2.size == 1

/-! ## A document -/

/-- The successor of `n`.

Relation to the source.
* **Translation.** `srcSucc n` is the paper's $n + 1$, written
  $\operatorname{succ}(n)$ there.
* **Formalisation note.** The paper works with *positive* integers;
  here `n : Nat` may be zero.

Proof. By definition. -/
def srcSucc (n : Nat) : Nat := n + 1

/-- Every number is below its successor.

Relation to the source.
* **Interpretation.** "Below" is read as the strict inequality `n < srcSucc n`.
* **Correction.** The printed statement omits the hypothesis $n \ge 0$.
* A bullet without a label.
* **Gap.** An unknown label.
-/
theorem srcSucc_gt (n : Nat) : n < srcSucc n := Nat.lt_succ_self n

set_option doc.verso true
set_option verso.blueprint.reviewLedger ".lake/source-annotations-test-ledger.json"

/--
warning: Verso.VersoBlueprintTests.SourceAnnotations.srcSucc_gt: a bullet of the "Relation to the source." section has no label (expected **Translation.**, **Interpretation.**, **Correction.** or **Formalisation note.**): A bullet without a label.
---
warning: Verso.VersoBlueprintTests.SourceAnnotations.srcSucc_gt: unknown label **Gap.** in the "Relation to the source." section (expected **Translation.**, **Interpretation.**, **Correction.** or **Formalisation note.**): **Gap.** An unknown label.
-/
#guard_msgs in
#docs (Manual) sourceAnnotationsDoc "Source annotations" :=
:::::::
:::definition "src.succ" (lean := "srcSucc")
The successor.
:::

::::theorem "src.gt" (lean := "srcSucc_gt, srcSucc")
Every number is below its successor.

:::translation (review := "reviewed EJ 2026-01-01")
A hand-written annotation.
:::
::::
:::::::

private def ledgerPath : System.FilePath := ".lake/source-annotations-test-ledger.json"

private def removeLedger : IO Unit := do
  if ← ledgerPath.pathExists then IO.FS.removeFile ledgerPath
  ReviewLedger.clearCache

-- Boxes, their order and decoration, math, and the docstring display without the section.
/-- info: true -/
#guard_msgs in
#eval! show IO Bool from do
  removeLedger
  let html ← renderManualDocHtmlString impls sourceAnnotationsDoc
  let succ := "Verso.VersoBlueprintTests.SourceAnnotations.srcSucc"
  pure <|
    -- two boxes at src.succ; at src.gt the hand-written one, then two from each declaration
    countSubstr html "class=\"bp-editorial\"" == 7 &&
    -- `data-decl` is also on the embedded declarations (srcSucc twice, srcSucc_gt once)
    countSubstr html s!"data-decl=\"{succ}\"" == 4 + 2 &&
    countSubstr html s!"data-decl=\"{succ}_gt\"" == 2 + 1 &&
    -- the declaration is named only where the node embeds several (relative to the open
    -- namespaces shown to a reader, which leave out `Verso`)
    countSubstr html "class=\"bp-editorial-decl\"" == 4 &&
    countSubstr html s!"bp-editorial-decl\"><code>{succ}_gt</code>" == 2 &&
    countSubstr html s!"bp-editorial-decl\"><code>{succ}</code>" == 2 &&
    appearsBefore html "aria-label=\"Interpretation\"" "aria-label=\"Correction\"" &&
    appearsBefore html "A hand-written annotation." "aria-label=\"Interpretation\"" &&
    hasSubstr html "aria-label=\"Formalisation note\"" &&
    -- Markdown: inline code, emphasis, inline math
    hasSubstr html "<code>srcSucc n</code>" &&
    hasSubstr html "<em>positive</em>" &&
    hasSubstr html "n + 1" &&
    hasSubstr html "\\operatorname{succ}(n)" &&
    countSubstr html "class=\"math inline\"" ≥ 3 &&
    -- the section is gone from srcSucc's docstring; srcSucc_gt keeps its two bad bullets
    hasSubstr html "Proof. By definition." &&
    countSubstr html "Relation to the source." == 1 &&
    hasSubstr html "A bullet without a label." &&
    -- no ledger: every docstring item is unreviewed; the hand-written badge is kept
    countSubstr html "data-review=\"unreviewed\">unreviewed" == 6 &&
    countSubstr html "reviewed EJ 2026-01-01" == 1

-- Review badges from the ledger, and the build option that hides them.
/-- info: true -/
#guard_msgs in
#eval! show IO Bool from do
  removeLedger
  let items := (SourceRelation.parse
    "Relation to the source.\n* **Translation.** `srcSucc n` is the paper's $n + 1$, written\n  $\\operatorname{succ}(n)$ there.").items
  let hash := items[0]!.hash
  IO.FS.writeFile ledgerPath s!"[
    \{\"decl\": \"Verso.VersoBlueprintTests.SourceAnnotations.srcSucc\", \"kind\": \"Translation\",
     \"hash\": \"{hash}\", \"reviewer\": \"BS\", \"date\": \"2026-10-01\"},
    \{\"decl\": \"Verso.VersoBlueprintTests.SourceAnnotations.srcSucc\", \"kind\": \"Formalisation note\",
     \"hash\": \"0000000000000000\", \"reviewer\": \"BS\", \"date\": \"2026-10-01\"}
  ]"
  let html ← renderManualDocHtmlString impls sourceAnnotationsDoc
  let reviewedOk :=
    countSubstr html "data-review=\"reviewed\">reviewed BS 2026-10-01" == 2 &&
    countSubstr html "data-review=\"changed\">changed since review" == 2 &&
    countSubstr html "data-review=\"unreviewed\">unreviewed" == 2 &&
    countSubstr html "reviewed EJ 2026-01-01" == 1
  ReviewLedger.setHideReview true
  let hidden ← renderManualDocHtmlString impls sourceAnnotationsDoc
  ReviewLedger.setHideReview false
  removeLedger
  let hiddenOk :=
    countSubstr hidden "class=\"bp-editorial\"" == 7 &&
    !hasSubstr hidden "bp-badge-review" &&
    !hasSubstr hidden "data-review=" &&
    !hasSubstr hidden "reviewed EJ"
  pure (reviewedOk && hiddenOk)

-- The generator's `--hide-review` flag is consumed and recorded.
/-- info: true -/
#guard_msgs in
#eval show IO Bool from do
  let rest ← ReviewLedger.takeHideReviewFlag ["--output", "_out", "--hide-review", "--verbose"]
  let hidden ← ReviewLedger.reviewHidden
  ReviewLedger.setHideReview false
  pure (rest == ["--output", "_out", "--verbose"] && hidden && !(← ReviewLedger.reviewHidden))

end Verso.VersoBlueprintTests.SourceAnnotations

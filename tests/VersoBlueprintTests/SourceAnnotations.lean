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
* **Remark.** An unknown label.

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
    .unknownLabel "Remark." "**Remark.** An unknown label."] &&
  p.remainder == "The successor of `n`.\n\nRelation to the source.\n* A bullet without a label.\n" ++
    "* **Remark.** An unknown label.\n\nProof. By definition." &&
  SourceRelation.stripSection "No section here.\n\nProof. Trivial." == "No section here.\n\nProof. Trivial." &&
  SourceRelation.stripSection "Text.\n\nRelation to the source.\n* **Correction.** A hypothesis.\n" ==
    "Text." &&
  (SourceRelation.parse "Text.\n\nRelation to the source.\nNo list here.").problems == #[.noItems] &&
  -- the period belongs inside the bold label
  (SourceRelation.parse "Relation to the source.\n* **Translation**. x").problems ==
    #[.unknownLabel "Translation" "**Translation**. x"] &&
  -- every label, in any order; each renders as the annotation kind of its title
  (SourceRelation.parse ("Relation to the source.\n* **Gap.** a\n* **Out of scope.** b\n" ++
      "* **Unformalised.** c\n* **Restatement.** d\n* **Strengthening.** e\n" ++
      "* **Interpretation.** f\n* **Correction.** g\n* **Translation.** h\n" ++
      "* **Formalisation note.** i")).items.map (fun i => (i.label.kindKey, i.markdown)) ==
    #[("gap", "a"), ("outOfScope", "b"), ("unformalised", "c"), ("restatement", "d"),
      ("strengthening", "e"), ("interpretation", "f"), ("correction", "g"), ("translation", "h"),
      ("meta", "i")] &&
  SourceRelation.Label.all.all (fun l =>
    (Editorial.Kind.ofKey? l.kindKey).map (·.title) == some l.text ||
      (l == .formalisationNote && l.kindKey == "meta")) &&
  -- labels are case-sensitive
  (SourceRelation.parse "Relation to the source.\n* **Out of Scope.** x").problems ==
    #[.unknownLabel "Out of Scope." "**Out of Scope.** x"]

/-! ## The ledger -/

/-- info: true -/
#guard_msgs in
#eval
  let entries : Array ReviewLedger.Entry := #[
    { decl := "A.b", kind := "Translation", hash := "0123456789abcdef", reviewer := "BS", date := "2026-10-01" },
    { decl := "A.b", kind := "Translation", hash := "0123456789abcdef", reviewer := "AS", date := "2026-10-02" },
    { decl := "A.b", kind := "Correction", hash := "1111111111111111", reviewer := "BS", date := "2026-10-01" }]
  -- an item alone of its kind: the latest matching review; a stale entry; no entry
  ReviewLedger.status entries "A.b" "Translation" #["0123456789abcdef"] 0 == .reviewed "AS" "2026-10-02" &&
  ReviewLedger.status entries "A.b" "Correction" #["0123456789abcdef"] 0 == .changedSinceReview &&
  ReviewLedger.status entries "A.b" "Interpretation" #["0123456789abcdef"] 0 == .unreviewed &&
  ReviewLedger.status entries "A.c" "Translation" #["0123456789abcdef"] 0 == .unreviewed &&
  ReviewLedger.status entries "A.b" "Translation" #["0123456789abcdef"] 1 == .unreviewed &&
  (ReviewLedger.parseLedger "[]").1.isEmpty &&
  (ReviewLedger.parseLedger "{}").2 == #["expected a JSON array of entries"] &&
  (ReviewLedger.parseLedger
    "[{\"decl\":\"A.b\",\"kind\":\"Remark\",\"hash\":\"0123456789abcdef\",\"reviewer\":\"BS\",\"date\":\"2026-10-01\"},
      {\"decl\":\"A.b\",\"kind\":\"Translation\",\"hash\":\"0123456789ABCDEF\",\"reviewer\":\"BS\",\"date\":\"2026-10-01\"},
      {\"decl\":\"A.b\",\"kind\":\"Translation\",\"hash\":\"0123456789abcdef\",\"reviewer\":\"BS\",\"date\":\"1 Oct\"},
      {\"decl\":\"A.b\",\"kind\":\"Translation\",\"hash\":\"0123456789abcdef\",\"reviewer\":\"BS\",\"date\":\"2026-10-01\"}]").1.size == 1 &&
  (ReviewLedger.parseLedger
    "[{\"decl\":\"A.b\",\"kind\":\"Remark\",\"hash\":\"0123456789abcdef\",\"reviewer\":\"BS\",\"date\":\"2026-10-01\"}]").2.size == 1

/-! ## Several items of one kind

The ledger's stale versions of a declaration and kind (hashes no current item of that kind has)
are paired with the unmatched items in docstring order. -/

private def h1 := "1111111111111111"   -- reviewed, unchanged
private def h2 := "2222222222222222"   -- the current text of an item edited after its review
private def h2old := "2020202020202020" -- that item's reviewed text
private def h3 := "3333333333333333"   -- the current text of a second edited item
private def h3old := "3030303030303030"
private def h4 := "4444444444444444"   -- never reviewed

private def review (decl kind hash : String) (reviewer := "BS") : ReviewLedger.Entry :=
  { decl, kind, hash, reviewer, date := "2026-10-01" }

/-- The state of each of the items `hashes` of `kind` in `decl`'s docstring, as badge states. -/
private def states (entries : Array ReviewLedger.Entry) (decl kind : String)
    (hashes : Array String) : List String :=
  (List.range hashes.size).map fun i =>
    match ReviewLedger.status entries decl kind hashes i with
    | .reviewed .. => "reviewed"
    | .changedSinceReview => "changed"
    | .unreviewed => "unreviewed"

/-- info: true -/
#guard_msgs in
#eval
  let base := #[review "A.d" "Translation" h1, review "A.d" "Translation" h2old]
  -- reviewed, edited after review, never reviewed
  states base "A.d" "Translation" #[h1, h2, h4] == ["reviewed", "changed", "unreviewed"] &&
  -- the position of the reviewed item does not matter
  states base "A.d" "Translation" #[h2, h1, h4] == ["changed", "reviewed", "unreviewed"] &&
  -- positional pairing: a new item before the edited one is the one flagged
  states base "A.d" "Translation" #[h4, h1, h2] == ["changed", "reviewed", "unreviewed"] &&
  -- two edited items of three, two stale versions
  states (base.push (review "A.d" "Translation" h3old)) "A.d" "Translation" #[h1, h2, h3] ==
    ["reviewed", "changed", "changed"] &&
  -- two reviews of the same old text are one stale version
  states (base.push (review "A.d" "Translation" h2old (reviewer := "AS"))) "A.d" "Translation"
    #[h1, h2, h4] == ["reviewed", "changed", "unreviewed"] &&
  -- an item deleted after its review leaves a stale version; the others are unaffected
  states base "A.d" "Translation" #[h1] == ["reviewed"] &&
  -- entries of another kind or another declaration are not stale versions of this pair
  states #[review "A.d" "Correction" h2old, review "A.e" "Translation" h2old] "A.d" "Translation"
    #[h2, h4] == ["unreviewed", "unreviewed"] &&
  -- reviewing one item of three changes nothing for the others
  states #[review "A.d" "Translation" h1] "A.d" "Translation" #[h1, h2, h4] ==
    ["reviewed", "unreviewed", "unreviewed"] &&
  -- two identical items share their review
  states #[review "A.d" "Translation" h1] "A.d" "Translation" #[h1, h1] == ["reviewed", "reviewed"]

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
* **Remark.** An unknown label.
-/
theorem srcSucc_gt (n : Nat) : n < srcSucc n := Nat.lt_succ_self n

/-- Three.

Relation to the source.
* **Translation.** `srcThree` is the paper's $3$.
* **Translation.** `srcThree` is written $\mathrm{III}$ in the paper.
* **Translation.** The paper's $3$ is a natural number.
* Twice the same bullet.
* Twice the same bullet.
-/
def srcThree : Nat := 3

/-- Four.

Relation to the source.
* **Restatement.** The paper writes $2 + 2$.
* **Strengthening.** The paper only says that four is positive.
* **Out of scope.** The paper's four in other bases.
-/
def srcFour : Nat := 4

/-- Five.

Relation to the source.
* **Gap.** The paper's five is prime; that is not stated.
* **Unformalised.** The paper's sixth number.
-/
def srcFive : Nat := 5

set_option doc.verso true
set_option verso.blueprint.reviewLedger ".lake/source-annotations-test-ledger.json"

/--
warning: Verso.VersoBlueprintTests.SourceAnnotations.srcSucc_gt: a bullet of the "Relation to the source." section has no label (expected **Translation.**, **Unformalised.**, **Out of scope.**, **Correction.**, **Interpretation.**, **Restatement.**, **Strengthening.**, **Gap.** or **Formalisation note.**): A bullet without a label.
---
warning: Verso.VersoBlueprintTests.SourceAnnotations.srcSucc_gt: unknown label **Remark.** in the "Relation to the source." section (expected **Translation.**, **Unformalised.**, **Out of scope.**, **Correction.**, **Interpretation.**, **Restatement.**, **Strengthening.**, **Gap.** or **Formalisation note.**): **Remark.** An unknown label.
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

-- Three items of one kind; two identical bad bullets give one warning at the node.
/--
warning: Verso.VersoBlueprintTests.SourceAnnotations.srcThree: a bullet of the "Relation to the source." section has no label (expected **Translation.**, **Unformalised.**, **Out of scope.**, **Correction.**, **Interpretation.**, **Restatement.**, **Strengthening.**, **Gap.** or **Formalisation note.**): Twice the same bullet.
-/
#guard_msgs in
#docs (Manual) threeItemsDoc "Three items" :=
:::::::
:::definition "src.three" (lean := "srcThree")
Three.
:::
:::::::

-- The states of the review badges in the HTML, in document order.
private def badgeStates (html : String) : List String :=
  (html.splitOn "class=\"bp-badge bp-badge-review\" data-review=\"").drop 1 |>.map fun piece =>
    (piece.splitOn "\"").headD ""

-- The values of the boxes' data-hash attributes in the HTML, in document order.
private def boxHashes (html : String) : List String :=
  (html.splitOn "data-hash=\"").drop 1 |>.map fun piece => (piece.splitOn "\"").headD ""

-- Reviewed, edited after its review, never reviewed: one badge each.
/-- info: true -/
#guard_msgs in
#eval! show IO Bool from do
  removeLedger
  let three := "Verso.VersoBlueprintTests.SourceAnnotations.srcThree"
  let reviewedHash := SourceRelation.itemHash "`srcThree` is the paper's $3$."
  let editedHash := SourceRelation.itemHash "`srcThree` is written $\\mathrm{III}$ in the paper."
  let newHash := SourceRelation.itemHash "The paper's $3$ is a natural number."
  -- the second item's text when it was reviewed
  let oldHash := SourceRelation.itemHash "`srcThree` is written III in the paper."
  IO.FS.writeFile ledgerPath s!"[
    \{\"decl\": \"{three}\", \"kind\": \"Translation\", \"hash\": \"{reviewedHash}\",
     \"reviewer\": \"BS\", \"date\": \"2026-10-01\"},
    \{\"decl\": \"{three}\", \"kind\": \"Translation\", \"hash\": \"{oldHash}\",
     \"reviewer\": \"BS\", \"date\": \"2026-09-01\"}
  ]"
  let html ← renderManualDocHtmlString impls threeItemsDoc
  -- with the first item's review alone, the other two are unreviewed
  IO.FS.writeFile ledgerPath s!"[
    \{\"decl\": \"{three}\", \"kind\": \"Translation\", \"hash\": \"{reviewedHash}\",
     \"reviewer\": \"BS\", \"date\": \"2026-10-01\"}
  ]"
  ReviewLedger.clearCache
  let oneReview ← renderManualDocHtmlString impls threeItemsDoc
  removeLedger
  pure <|
    boxHashes html == [reviewedHash, editedHash, newHash] &&
    badgeStates html == ["reviewed", "changed", "unreviewed"] &&
    countSubstr html "reviewed BS 2026-10-01" == 1 &&
    badgeStates oneReview == ["reviewed", "unreviewed", "unreviewed"] &&
    -- the two bad bullets stay in the docstring display
    countSubstr html "Twice the same bullet." == 2

-- The comparison kinds: every label renders as the annotation kind of its title; an item from a
-- docstring never puts the "Owes work" badge on its node, whatever its kind.
#docs (Manual) comparisonKindsDoc "Comparison kinds" :=
:::::::
:::definition "src.four" (lean := "srcFour")
Four.
:::

:::definition "src.five" (lean := "srcFive")
Five.
:::
:::::::

/-- info: true -/
#guard_msgs in
#eval! show IO Bool from do
  removeLedger
  let html ← renderManualDocHtmlString impls comparisonKindsDoc
  pure <|
    countSubstr html "class=\"bp-editorial\"" == 5 &&
    hasSubstr html "data-kind=\"restatement\"" && hasSubstr html "aria-label=\"Restatement\"" &&
    hasSubstr html "data-kind=\"strengthening\"" && hasSubstr html "aria-label=\"Strengthening\"" &&
    hasSubstr html "data-kind=\"outOfScope\"" && hasSubstr html "aria-label=\"Out of scope\"" &&
    hasSubstr html "data-kind=\"gap\"" && hasSubstr html "aria-label=\"Gap\"" &&
    hasSubstr html "data-kind=\"unformalised\"" && hasSubstr html "aria-label=\"Unformalised\"" &&
    -- no `missing` badge on an item from a docstring
    !hasSubstr html "bp-badge-missing" &&
    -- no header badge
    countSubstr html "class=\"bp-correspondence-warning\"" == 0

-- The generator's `--hide-review` flag is consumed and recorded.
/-- info: true -/
#guard_msgs in
#eval show IO Bool from do
  let rest ← ReviewLedger.takeHideReviewFlag ["--output", "_out", "--hide-review", "--verbose"]
  let hidden ← ReviewLedger.reviewHidden
  ReviewLedger.setHideReview false
  pure (rest == ["--output", "_out", "--verbose"] && hidden && !(← ReviewLedger.reviewHidden))

end Verso.VersoBlueprintTests.SourceAnnotations

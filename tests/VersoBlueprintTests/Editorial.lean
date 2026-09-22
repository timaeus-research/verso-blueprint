import VersoBlueprintTests.Blueprint.Support

open Lean Verso Genre Manual Informal
open Verso.VersoBlueprintTests.Blueprint.Support

private def impls : ExtensionImpls := extension_impls%

set_option doc.verso true

#docs (Manual) editorialDoc "Editorial annotations" :=
:::::::
:::definition "editorial.threshold"
The successor threshold.
:::

```lean "editorial.threshold"
def editorialThreshold (n : Nat) : Nat := n + 1
```

:::translation
`editorialThreshold n` is the paper's $`n + 1`; the notation {Verso.Genre.Manual.InlineLean.lean}`Nat` retains its Lean hover information.
:::
:::meta
Proof implementation lives in an imported module.
:::
:::interpretation (review := "reviewed EJ 2026-01-01")
The successor convention is explicit in the preceding definition.
:::
:::correction
A correction annotation explains linked evidence; it does not certify a proof.
:::
:::missingHypothesis
The paper's statement needs the threshold to be positive; the formal statement adds it.
:::
:::strengthening
The formal statement is for every natural number where the paper has positive ones.
:::
:::restatement
The formal statement is the paper's, with the two clauses in the other order.
:::
:::outOfScope
An unused variant is omitted; no retained result depends on it.
:::
::::theorem "editorial.fixture"
Mathematical statement remains ordinary prose.

:::formalizationTodo
The statements differ. Restate the paper's claim, prove equivalence, or
establish a counterexample and exact negation supporting a correction.
The threshold {Verso.Genre.Manual.InlineLean.lean}`editorialThreshold 1`
was declared in a preceding Lean block.
:::
::::
::::theorem "editorial.owed"
A statement with the two kinds that owe work.

:::gap
The paper's clause (2) is missing from the formal statement; stating it is proof work.
:::
:::unformalised (missing := statement)
The paper's corollary has no formal statement; untried.
:::
::::
:::::::

/-- info: true -/
#guard_msgs in
#eval! do
  let html ← renderManualDocHtmlString impls editorialDoc
  pure <| countSubstr html "class=\"bp-editorial\"" == 11 &&
    hasSubstr html "data-kind=\"translation\"" &&
    hasSubstr html "data-kind=\"meta\"" &&
    hasSubstr html "data-kind=\"interpretation\"" &&
    hasSubstr html "data-kind=\"correction\"" &&
    hasSubstr html "data-kind=\"missingHypothesis\"" &&
    hasSubstr html "aria-label=\"Missing hypothesis\"" &&
    hasSubstr html "data-kind=\"strengthening\"" &&
    hasSubstr html "data-kind=\"restatement\"" &&
    hasSubstr html "data-kind=\"outOfScope\"" &&
    hasSubstr html "data-kind=\"formalizationTodo\"" &&
    hasSubstr html "data-kind=\"gap\"" &&
    hasSubstr html "data-kind=\"unformalised\"" &&
    hasSubstr html "aria-label=\"Interpretation\"" &&
    hasSubstr html "aria-label=\"Correction\"" &&
    hasSubstr html "aria-label=\"Strengthening\"" &&
    hasSubstr html "aria-label=\"Restatement\"" &&
    hasSubstr html "aria-label=\"Out of scope\"" &&
    hasSubstr html "aria-label=\"Translation\"" &&
    hasSubstr html "aria-label=\"Gap\"" &&
    hasSubstr html "aria-label=\"Unformalised\"" &&
    countSubstr html "data-review=\"reviewed\"" == 2 &&
    hasSubstr html "reviewed EJ 2026-01-01" &&
    countSubstr html "class=\"bp-badge bp-badge-review\"" == 11 &&
    hasSubstr html "class=\"bp-badge bp-badge-missing\">missing: statement" &&
    countSubstr html "class=\"bp-correspondence-warning\"" == 2 &&
    !(hasSubstr html "Formalization gap") &&
    hasSubstr html "data-verso-hover" &&
    !(hasSubstr html "<details class=\"bp-editorial")

/-- info: true -/
#guard_msgs in
#eval show IO Bool from do
  let mk (kind : String) : Doc.Block Manual :=
    .other (Editorial.Block.editorial kind "unreviewed" "") #[]
  let ext := Editorial.Block.editorial "formalizationTodo" "unreviewed" ""
  let data ← IO.ofExcept (fromJson? (α := Editorial.Annotation) ext.data)
  let block : Doc.Block Manual := .other ext #[.para #[.text "Outstanding"]]
  return data.kind == .formalizationTodo && Editorial.hasFormalizationTodo (.blockquote #[block]) &&
    Editorial.hasFormalizationTodo (mk "gap") &&
    Editorial.hasFormalizationTodo (mk "unformalised") &&
    !Editorial.hasFormalizationTodo (mk "translation") &&
    !Editorial.hasFormalizationTodo (mk "restatement") &&
    !Editorial.hasFormalizationTodo (mk "interpretation") &&
    !Editorial.hasFormalizationTodo (mk "correction") &&
    !Editorial.hasFormalizationTodo (mk "missingHypothesis") &&
    !Editorial.hasFormalizationTodo (mk "strengthening") &&
    !Editorial.hasFormalizationTodo (mk "outOfScope") &&
    Editorial.hasFormalizationTodo (.other (Editorial.Block.editorial "correction" "unreviewed" "") #[block]) &&
    (Editorial.Review.parse? "reviewed BS 2026-09-22" == some (.reviewed "BS" "2026-09-22")) &&
    (Editorial.Review.parse? "unreviewed" == some .unreviewed) &&
    (Editorial.Review.parse? "reviewed" == none)

set_option verso.blueprint.foldProofBlocks true
#docs (Manual) omittedProofDoc "Statement with omitted proof" :=
:::::::
::::theorem "editorial.omitted.fixture"
A faithful statement whose proof is deliberately omitted.
:::interpretation
The mathematical convention is explicit in the statement.
:::
:::outOfScope
An unused generalization is not included in this statement.
:::
::::
:::proof "editorial.omitted.fixture"
Proof omitted.
:::
:::::::

/-- info: true -/
#guard_msgs in
#eval! do
  let html ← renderManualDocHtmlString impls omittedProofDoc
  pure <| !(hasSubstr html "class=\"bp-correspondence-warning\"") &&
    hasSubstr html "data-kind=\"interpretation\"" &&
    hasSubstr html "<details class=\"bp_wrapper bp_kind_proof_wrapper"

#docs (Manual) proofGapDoc "Proof gap" :=
:::::::
:::theorem "editorial.proof.fixture"
Statement whose proof note reveals an outstanding correspondence obligation.
:::
::::proof "editorial.proof.fixture"
:::gap
An equivalence is still missing.
:::
::::
:::::::

/-- info: true -/
#guard_msgs in
#eval! do
  let html ← renderManualDocHtmlString impls proofGapDoc
  pure <| countSubstr html "class=\"bp-correspondence-warning\"" == 2 &&
    !(hasSubstr html "<details class=\"bp_wrapper bp_kind_proof_wrapper")

/-- info: true -/
#guard_msgs in
#eval show IO Bool from do
  let entry : PreviewManifest.Entry := {
    key := "fixture", targetKind := .block, label := `fixture,
    facet := .statement, title := "Fixture", hasFormalizationTodo := true }
  let restored ← IO.ofExcept (fromJson? (α := PreviewManifest.Entry) (toJson entry))
  let data := restored.blockData
  return data.hasFormalizationTodo &&
    hasSubstr (renderInformalBlockHtml data (.forBlock data "1") #[]).asString
      "Formalisation TODO"

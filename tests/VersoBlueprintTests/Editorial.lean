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
The notation {Verso.Genre.Manual.InlineLean.lean}`Nat` retains its Lean hover information.
:::
:::meta
Proof implementation lives in an imported module.
:::
::::theorem "editorial.fixture"
Mathematical statement remains ordinary prose.

:::formalizationGap
The equivalence lemma is still missing. This is not a completed correspondence.
The threshold {Verso.Genre.Manual.InlineLean.lean}`editorialThreshold 1`
was declared in a preceding Lean block.
:::
::::
:::::::

/-- info: true -/
#guard_msgs in
#eval! do
  let html ← renderManualDocHtmlString impls editorialDoc
  pure <| countSubstr html "class=\"bp-editorial\"" == 3 &&
    hasSubstr html "data-kind=\"translation\"" &&
    hasSubstr html "data-kind=\"meta\"" &&
    hasSubstr html "data-kind=\"formalizationGap\"" &&
    hasSubstr html "Formalization gap" &&
    !(hasSubstr html "A proof-status badge concerns") &&
    !(hasSubstr html "Unresolved statement discrepancy") &&
    hasSubstr html "data-verso-hover" &&
    !(hasSubstr html "<details class=\"bp-editorial")

/-- info: true -/
#guard_msgs in
#eval show IO Bool from do
  let ext := Editorial.Block.editorial .formalizationGap
  let data ← IO.ofExcept (fromJson? (α := Editorial.Kind) ext.data)
  let block : Doc.Block Manual := .other ext #[.para #[.text "Outstanding"]]
  return data == .formalizationGap && Editorial.hasFormalizationGap (.blockquote #[block]) &&
    !Editorial.hasFormalizationGap (.other (Editorial.Block.editorial .translation) #[])

set_option verso.blueprint.foldProofBlocks true
#docs (Manual) proofGapDoc "Proof gap" :=
:::::::
:::theorem "editorial.proof.fixture"
Statement whose proof note reveals an outstanding correspondence obligation.
:::
::::proof "editorial.proof.fixture"
:::formalizationGap
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
    facet := .statement, title := "Fixture", hasFormalizationGap := true }
  let restored ← IO.ofExcept (fromJson? (α := PreviewManifest.Entry) (toJson entry))
  let data := restored.blockData
  return data.hasFormalizationGap &&
    hasSubstr (renderInformalBlockHtml data (.forBlock data "1") #[]).asString
      "Formalization gap"

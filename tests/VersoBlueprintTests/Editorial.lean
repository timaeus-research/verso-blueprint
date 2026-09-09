import VersoBlueprintTests.Blueprint.Support

open Lean Verso Genre Manual Informal
open Verso.VersoBlueprintTests.Blueprint.Support

private def impls : ExtensionImpls := extension_impls%

set_option doc.verso true

#docs (Manual) editorialDoc "Editorial annotations" :=
:::::::
:::translation
The notation {Verso.Genre.Manual.InlineLean.lean}`Nat` retains its Lean hover information.
:::
:::meta
Proof implementation lives in an imported module.
:::
::::theorem "editorial.fixture"
Mathematical statement remains ordinary prose.

:::discrepancy
The equivalence lemma is still missing. This is not a completed correspondence.
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
    hasSubstr html "data-kind=\"discrepancy\"" &&
    hasSubstr html "Unresolved statement discrepancy" &&
    hasSubstr html Editorial.discrepancyCaveat &&
    hasSubstr html "Statement correspondence unresolved" &&
    hasSubstr html "data-verso-hover" &&
    !(hasSubstr html "<details class=\"bp-editorial")

/-- info: true -/
#guard_msgs in
#eval show IO Bool from do
  let ext := Editorial.Block.editorial .discrepancy
  let data ← IO.ofExcept (fromJson? (α := Editorial.Kind) ext.data)
  let block : Doc.Block Manual := .other ext #[.para #[.text "Outstanding"]]
  return data == .discrepancy && Editorial.hasDiscrepancy (.blockquote #[block]) &&
    !Editorial.hasDiscrepancy (.other (Editorial.Block.editorial .translation) #[])

set_option verso.blueprint.foldProofBlocks true
#docs (Manual) proofDiscrepancyDoc "Proof discrepancy" :=
:::::::
:::theorem "editorial.proof.fixture"
Statement whose proof note reveals an outstanding correspondence obligation.
:::
::::proof "editorial.proof.fixture"
:::discrepancy
An equivalence is still missing.
:::
::::
:::::::

/-- info: true -/
#guard_msgs in
#eval! do
  let html ← renderManualDocHtmlString impls proofDiscrepancyDoc
  pure <| countSubstr html "Statement correspondence unresolved" == 2 &&
    !(hasSubstr html "<details class=\"bp_wrapper bp_kind_proof_wrapper")

/-- info: true -/
#guard_msgs in
#eval show IO Bool from do
  let entry : PreviewManifest.Entry := {
    key := "fixture", targetKind := .block, label := `fixture,
    facet := .statement, title := "Fixture", hasStatementDiscrepancy := true }
  let restored ← IO.ofExcept (fromJson? (α := PreviewManifest.Entry) (toJson entry))
  let data := restored.blockData
  return data.hasStatementDiscrepancy &&
    hasSubstr (renderInformalBlockHtml data (.forBlock data "1") #[]).asString
      "Statement correspondence unresolved"

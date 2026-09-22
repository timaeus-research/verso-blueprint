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
:::clarification
The successor convention is explicit in the preceding definition.
:::
:::correction
A correction annotation explains linked evidence; it does not certify a proof.
:::
:::deviation
The formal statement is for every natural number where the paper has positive ones; it is
stronger, and nothing is owed.
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
::::theorem "editorial.refined"
A statement with the three refined TODO kinds.

:::todoProof
The paper's clause (2) is formalisable with the current definitions; only its proof is missing.
:::
:::todoFormulation
The paper's partition of unity needs a Lean formulation before its clause can be stated.
:::
:::todoHard
Whether the paper's hypothesis is redundant is open.
:::
::::
:::::::

/-- info: true -/
#guard_msgs in
#eval! do
  let html ← renderManualDocHtmlString impls editorialDoc
  pure <| countSubstr html "class=\"bp-editorial\"" == 10 &&
    hasSubstr html "data-kind=\"translation\"" &&
    hasSubstr html "data-kind=\"meta\"" &&
    hasSubstr html "data-kind=\"formalizationTodo\"" &&
    hasSubstr html "data-kind=\"todoProof\"" &&
    hasSubstr html "data-kind=\"todoFormulation\"" &&
    hasSubstr html "data-kind=\"todoHard\"" &&
    hasSubstr html "data-kind=\"clarification\"" &&
    hasSubstr html "data-kind=\"correction\"" &&
    hasSubstr html "data-kind=\"deviation\"" &&
    hasSubstr html "aria-label=\"Clarification\"" &&
    hasSubstr html "aria-label=\"Correction\"" &&
    hasSubstr html "aria-label=\"Deviation by choice\"" &&
    hasSubstr html "aria-label=\"Formalisation TODO: proof work\"" &&
    hasSubstr html "aria-label=\"Formalisation TODO: formulation\"" &&
    hasSubstr html "aria-label=\"Formalisation TODO: hard\"" &&
    hasSubstr html "data-kind=\"outOfScope\"" &&
    hasSubstr html "aria-label=\"Out of scope\"" &&
    hasSubstr html "Formalisation TODO" &&
    hasSubstr html "class=\"bp-correspondence-warning\"" &&
    !(hasSubstr html "Formalization gap") &&
    !(hasSubstr html "A proof-status badge concerns") &&
    !(hasSubstr html "Unresolved statement discrepancy") &&
    hasSubstr html "data-verso-hover" &&
    !(hasSubstr html "<details class=\"bp-editorial")

/-- info: true -/
#guard_msgs in
#eval show IO Bool from do
  let ext := Editorial.Block.editorial .formalizationTodo
  let data ← IO.ofExcept (fromJson? (α := Editorial.Kind) ext.data)
  let block : Doc.Block Manual := .other ext #[.para #[.text "Outstanding"]]
  return data == .formalizationTodo && Editorial.hasFormalizationTodo (.blockquote #[block]) &&
    Editorial.hasFormalizationTodo (.other (Editorial.Block.editorial .todoProof) #[]) &&
    Editorial.hasFormalizationTodo (.other (Editorial.Block.editorial .todoFormulation) #[]) &&
    Editorial.hasFormalizationTodo (.other (Editorial.Block.editorial .todoHard) #[]) &&
    !Editorial.hasFormalizationTodo (.other (Editorial.Block.editorial .translation) #[]) &&
    !Editorial.hasFormalizationTodo (.other (Editorial.Block.editorial .clarification) #[]) &&
    !Editorial.hasFormalizationTodo (.other (Editorial.Block.editorial .correction) #[]) &&
    !Editorial.hasFormalizationTodo (.other (Editorial.Block.editorial .deviation) #[]) &&
    Editorial.hasFormalizationTodo (.other (Editorial.Block.editorial .correction) #[block]) &&
    !Editorial.hasFormalizationTodo (.other (Editorial.Block.editorial .outOfScope) #[]) &&
    Editorial.hasFormalizationTodo (.other (Editorial.Block.editorial .outOfScope) #[block])

set_option verso.blueprint.foldProofBlocks true
#docs (Manual) omittedProofDoc "Statement with omitted proof" :=
:::::::
::::theorem "editorial.omitted.fixture"
A faithful statement whose proof is deliberately omitted.
:::clarification
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
    hasSubstr html "data-kind=\"clarification\"" &&
    hasSubstr html "<details class=\"bp_wrapper bp_kind_proof_wrapper"

#docs (Manual) proofGapDoc "Proof gap" :=
:::::::
:::theorem "editorial.proof.fixture"
Statement whose proof note reveals an outstanding correspondence obligation.
:::
::::proof "editorial.proof.fixture"
:::todoProof
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

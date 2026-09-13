/- 
Copyright (c) 2026 Lean FRO LLC. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Author: Emilio J. Gallego Arias
-/

import VersoBlueprintTests.Blueprint.Support

namespace Verso.VersoBlueprintTests.BlueprintCodeRenderMatrix

open Lean
open Informal
open Informal.Data
open Verso.VersoBlueprintTests.Blueprint.Support

private def provedExternalRef (name : Lean.Name) (kind : Data.NodeKind := .definition) : Data.ExternalRef :=
  {
    (Data.ExternalRef.ofName name) with
      present := true
      kind
  }

private def sorryExternalRef (name : Lean.Name) (kind : Data.NodeKind := .theorem) : Data.ExternalRef :=
  {
    (Data.ExternalRef.ofName name) with
      present := true
      kind
      provedStatus := .containsSorry #[{ location := .proof, refs? := some 1 }]
  }

private def axiomExternalRef (name : Lean.Name) (kind : Data.NodeKind := .theorem) : Data.ExternalRef :=
  {
    (Data.ExternalRef.ofName name) with
      present := true
      kind
      provedStatus := .axiomLike
  }

private def missingExternalRef (name : Lean.Name) (kind : Data.NodeKind := .definition) : Data.ExternalRef :=
  {
    (Data.ExternalRef.ofName name) with
      present := false
      kind
  }

private def renderFailedExternalRef (name : Lean.Name) (kind : Data.NodeKind := .theorem) : Data.ExternalRef :=
  {
    (Data.ExternalRef.ofName name) with
      present := true
      kind
      render := .error (.exception name "synthetic render failure")
  }

private def statementData (label : Name) (kind : Data.NodeKind) (source : Option BlockCodeData) : BlockData :=
  {
    kind := .statement kind
    codeData := source
    label
    count := 1
  }

private def inlineCode (declStatus : Data.ProvedStatus) : InlineCodeData :=
  {
    label := `inline.status
    definedDefs := #[{ name := `Inline.status, provedStatus := declStatus }]
  }

private def codeEntryHtml (label : Name) (kind : Data.NodeKind) (source : Option BlockCodeData) : String :=
  let data := statementData label kind source
  (CodeSummary.renderParts data { source } (fun _ => none)).codeEntry.asString

private def panelIndicatorHtml (label : Name) (source : BlockCodeData) : String :=
  (CodeSummary.renderPanelIndicator label { source := some source } (fun _ => none)).indicator.asString

/-- info: true -/
#guard_msgs in
#eval!
  let inlineProvedHtml := codeEntryHtml `inline.proved .definition (some (.inline (inlineCode .proved)))
  let inlineSorryHtml := codeEntryHtml `inline.sorry .definition (some (.inline (inlineCode (.containsSorry #[{ location := .proof, refs? := some 1 }]))))
  let inlineAxiomHtml := codeEntryHtml `inline.axiom .definition (some (.inline (inlineCode .axiomLike)))
  hasSubstr inlineProvedHtml "bp_code_link_status_proved" &&
    hasSubstr inlineSorryHtml "bp_code_link_status_warning" &&
    hasSubstr inlineAxiomHtml "bp_code_link_status_axiom" &&
    hasSubstr (codeEntryHtml `inline.absent .definition none) "bp_code_link_status_absent"

/-- info: true -/
#guard_msgs in
#eval!
  hasSubstr
      (codeEntryHtml `external.missing .definition (some (.external #[missingExternalRef `Ext.missing])))
      "bp_code_link_status_missing"

/-- info: true -/
#guard_msgs in
#eval!
  hasSubstr
      (codeEntryHtml `external.axiom .theorem (some (.external #[axiomExternalRef `Ext.axiom])))
      "bp_code_link_status_axiom"

/-- info: true -/
#guard_msgs in
#eval!
  let externalRenderFailHtml := codeEntryHtml `external.render_fail .theorem (some (.external #[renderFailedExternalRef `Ext.renderFail]))
  hasSubstr externalRenderFailHtml "bp_code_link_status_proved" &&
    hasSubstr externalRenderFailHtml "bp_code_render_warning_badge" &&
    appearsBefore externalRenderFailHtml "bp_code_render_warning_badge" "bp_code_status_symbol"

/-- info: true -/
#guard_msgs in
#eval!
  let externalOkHtml := panelIndicatorHtml `external.ok (.external #[provedExternalRef `Ext.ok .definition])
  let externalSorryHtml := panelIndicatorHtml `external.sorry (.external #[sorryExternalRef `Ext.sorry .theorem])
  let externalMissingHtml := panelIndicatorHtml `external.missing (.external #[missingExternalRef `Ext.missing .definition])
  let externalAxiomHtml := panelIndicatorHtml `external.axiom (.external #[axiomExternalRef `Ext.axiom .theorem])
  let externalRenderFailHtml := panelIndicatorHtml `external.render_fail (.external #[renderFailedExternalRef `Ext.renderFail .theorem])
  hasSubstr externalOkHtml "bp_external_status_badge_summary bp_external_status_ok" &&
    hasSubstr externalSorryHtml "bp_external_status_badge_summary bp_external_status_sorry" &&
    hasSubstr externalMissingHtml "bp_external_status_badge_summary bp_external_status_missing" &&
    hasSubstr externalAxiomHtml "bp_code_decl_status_axiom" &&
    !hasSubstr externalRenderFailHtml "bp_code_render_warning_badge" &&
    !hasSubstr externalRenderFailHtml "bp_render_warning_badge" &&
    hasSubstr externalRenderFailHtml "synthetic render failure"

open Verso Genre Manual

private def repeatedImpls : ExtensionImpls := extension_impls%

#docs (Manual) repeatedCodeDoc "Repeated code ownership" :=
:::::::
:::theorem "repeated.forward"
A helper and its theorem may have separate code panels.
:::

```lean "repeated.forward"
open Nat
```

```lean "repeated.forward"
def repeatedForwardHelper : Nat := 0
```

The proof is displayed after the setup.

```lean "repeated.forward"
theorem repeatedForwardClaim :
    repeatedForwardHelper = 0 := by
  sorry
```

:::theorem "repeated.reverse"
A theorem can precede a separate definition.
:::

```lean "repeated.reverse" (autoDeps := true)
theorem repeatedReverseClaim : True := by
  have := repeatedForwardClaim
  sorry
```

```lean "repeated.reverse" (autoDeps := true)
def repeatedReverseHelper :
    Fin (repeatedForwardHelper + 1) := 0
```

:::theorem "repeated.theorems"
A later incomplete theorem changes the aggregate status.
:::

```lean "repeated.theorems"
theorem repeatedProvedClaim : True := by trivial
```

```lean "repeated.theorems"
theorem repeatedLaterClaim : True := by sorry
```
:::::::

private def repeatedLogger : Logger IO where
  log _ _ _ := pure ()
  errors := pure #[]
  warnings := pure #[]

/-- info: true -/
#guard_msgs in
#eval show IO Bool from do
  let (html, st) ← renderManualDocHtmlStringAndState repeatedImpls repeatedCodeDoc
  let (blocks, _) ← traverseManualDocBlocksAndState repeatedImpls repeatedCodeDoc
  let (_, st') ←
    (TraverseM.run repeatedImpls {} st <| blocks.mapM Verso.Genre.Manual.traverseBlock)
      |>.run repeatedLogger
  let some forward := TraversalIndex.InlineCode.data? st `«repeated.forward»
    | throw <| IO.userError "Missing forward index"
  let some reverse := TraversalIndex.InlineCode.data? st `«repeated.reverse»
    | throw <| IO.userError "Missing reverse index"
  let key := TraversalIndex.LeanCodePreviews.lookupInlineKey `«repeated.forward»
  let some obj := TraversalIndex.LeanCodePreviews.object? st key
    | throw <| IO.userError "Missing inline preview"
  let .ok preview := fromJson? (α := LeanCodePreview.Entry) obj.data
    | throw <| IO.userError "Invalid inline preview"
  let .inlineBlocks previewBlocks _ := preview.source
    | throw <| IO.userError "Wrong preview kind"
  let files ← buildManualPreviewDataFiles repeatedImpls repeatedCodeDoc
  let exported := (toJson files.manifest).compress
  let ids := (html.splitOn " id=\"").drop 1 |>.map (fun s => (s.splitOn "\"").head!)
  let some exportedForward := files.manifest.previews.find?
      (fun entry => entry.label == `«repeated.forward» && entry.kind.isSome)
    | throw <| IO.userError "Missing exported node"
  let some (.inline exportedCode) := exportedForward.codeData
    | throw <| IO.userError "Missing exported inline code"
  for (name, ok) in #[
    ("idempotence", st == st'),
    ("unique rendered ids", ids.eraseDups.length == ids.length),
    ("single stable code target", (TraversalIndex.InlineCode.object? st
      `«repeated.forward»).any (fun obj => obj.ids.size == 1)),
    ("forward declarations", forward.definedDefs.size == 1 && forward.definedTheorems.size == 1),
    ("reverse declarations", reverse.definedDefs.size == 1 && reverse.definedTheorems.size == 1),
    ("later statement dependency", reverse.statementUses.any (·.label == `«repeated.forward»)),
    ("proof dependency", reverse.proofUses.any (·.label == `«repeated.forward»)),
    ("preview setup and both bodies", previewBlocks.size == 3),
    ("all node badges", countSubstr html "bp_code_link_status_warning" == 3),
    ("no false complete badge", !hasSubstr html "bp_code_link_status_proved"),
    ("local and aggregate popups", countSubstr html "bp_code_decl_status_warning" == 6),
    ("exported code matches node", toJson exportedCode == toJson forward),
    ("reverse source order", reverse.definedTheorems[0]!.commandIndex <
      reverse.definedDefs[0]!.commandIndex),
    ("exported declarations", #["repeatedForwardClaim", "repeatedForwardHelper",
      "repeatedReverseClaim", "repeatedReverseHelper"].all (hasSubstr exported))] do
    unless ok do throw <| IO.userError s!"Repeated-code regression failed: {name}"
  return true

end Verso.VersoBlueprintTests.BlueprintCodeRenderMatrix

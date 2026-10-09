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
    kind := kind
    codeData := source
    label
    count := 1
  }

private def inlineCode (declStatus : Data.ProvedStatus) : InlineCodeBlocks :=
  #[{
    blockId := `matrix.inline
    label := `inline.status
    definedDefs := #[{ name := `Inline.status, provedStatus := declStatus }]
  }]

private def codeEntryHtml (label : Name) (kind : Data.NodeKind) (source : Option BlockCodeData) : String :=
  let data := statementData label kind source
  (CodeSummary.renderParts data { source } (fun _ => none)).codeEntry.asString

private def panelIndicatorHtml (label : Name) (source : BlockCodeData) : String :=
  (CodeSummary.renderPanelIndicator label { source := some source } (fun _ => none)).indicator.asString

/-- info: true -/
#guard_msgs in
#eval!
  let inlineProvedHtml := codeEntryHtml `inline.proved .definition (some { literateDeclarations := (inlineCode .proved).literateDeclarations })
  let inlineSorryHtml := codeEntryHtml `inline.sorry .definition (some { literateDeclarations := (inlineCode (.containsSorry #[{ location := .proof, refs? := some 1 }])).literateDeclarations })
  let inlineAxiomHtml := codeEntryHtml `inline.axiom .definition (some { literateDeclarations := (inlineCode .axiomLike).literateDeclarations })
  hasSubstr inlineProvedHtml "bp_code_link_status_proved" &&
    hasSubstr inlineSorryHtml "bp_code_link_status_warning" &&
    hasSubstr inlineAxiomHtml "bp_code_link_status_axiom" &&
    hasSubstr (codeEntryHtml `inline.absent .definition none) "bp_code_link_status_absent"

/-- info: true -/
#guard_msgs in
#eval!
  hasSubstr
      (codeEntryHtml `external.missing .definition (some { externalDecls := #[missingExternalRef `Ext.missing] }))
      "bp_code_link_status_missing"

/-- info: true -/
#guard_msgs in
#eval!
  hasSubstr
      (codeEntryHtml `external.axiom .theorem (some { externalDecls := #[axiomExternalRef `Ext.axiom] }))
      "bp_code_link_status_axiom"

/-- info: true -/
#guard_msgs in
#eval!
  let externalRenderFailHtml := codeEntryHtml `external.render_fail .theorem (some { externalDecls := #[renderFailedExternalRef `Ext.renderFail] })
  hasSubstr externalRenderFailHtml "bp_code_link_status_proved" &&
    hasSubstr externalRenderFailHtml "bp_code_render_warning_badge" &&
    appearsBefore externalRenderFailHtml "bp_code_render_warning_badge" "bp_code_status_symbol"

/-- info: true -/
#guard_msgs in
#eval!
  let externalOkHtml := panelIndicatorHtml `external.ok { externalDecls := #[provedExternalRef `Ext.ok .definition] }
  let externalSorryHtml := panelIndicatorHtml `external.sorry { externalDecls := #[sorryExternalRef `Ext.sorry .theorem] }
  let externalMissingHtml := panelIndicatorHtml `external.missing { externalDecls := #[missingExternalRef `Ext.missing .definition] }
  let externalAxiomHtml := panelIndicatorHtml `external.axiom { externalDecls := #[axiomExternalRef `Ext.axiom .theorem] }
  let externalRenderFailHtml := panelIndicatorHtml `external.render_fail { externalDecls := #[renderFailedExternalRef `Ext.renderFail .theorem] }
  hasSubstr externalOkHtml "bp_external_status_badge_summary bp_external_status_ok" &&
    hasSubstr externalSorryHtml "bp_external_status_badge_summary bp_external_status_sorry" &&
    hasSubstr externalMissingHtml "bp_external_status_badge_summary bp_external_status_missing" &&
    hasSubstr externalAxiomHtml "bp_code_decl_status_axiom" &&
    !hasSubstr externalRenderFailHtml "bp_code_render_warning_badge" &&
    !hasSubstr externalRenderFailHtml "bp_render_warning_badge" &&
    hasSubstr externalRenderFailHtml "synthetic render failure"

-- A heading summarizes the union, even when literate code has its own panel.
#eval show IO Unit from do
  let source : BlockCodeData := {
    literateDeclarations := (inlineCode .proved).literateDeclarations
    externalDecls := #[sorryExternalRef `Ext.mixed .theorem] }
  let html := codeEntryHtml `mixed .theorem (some source)
  unless hasSubstr html "bp_code_link_status_warning" && hasSubstr html "Ext.mixed" &&
      source.literateDeclarations.declarations.all (fun decl => hasSubstr html decl.name.toString) do
    throw <| IO.userError "Mixed associations lost a declaration or hid its incomplete status"

-- The same canonical declaration is counted once, using its literate definition.
#eval show IO Unit from do
  let blocks := inlineCode .proved
  let declaration := blocks.declarations[0]!
  let external := missingExternalRef declaration.name
  let source : BlockCodeData := { literateDeclarations := blocks.literateDeclarations, externalDecls := #[external] }
  let headingHealth := Graph.codeHealthOfBlockSource .definition {} (some source)
  let node : Data.Node := {
    externalRefs := #[external]
    literateCodes := #[{ stx := .missing, definedDefs := #[{ name := declaration.name }] }] }
  let nodeHealth := Graph.nodeCodeHealth {} node
  unless headingHealth.totalDecls == 1 && nodeHealth.totalDecls == 1 &&
      headingHealth.missingDecls == 0 && nodeHealth.missingDecls == 0 do
    throw <| IO.userError "Associated declarations disagreed between heading and graph status"

-- Several code blocks may share one label, with prose between them.
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
  let forward := TraversalIndex.InlineCode.blocks st `«repeated.forward»
  let reverse := TraversalIndex.InlineCode.blocks st `«repeated.reverse»
  let files ← buildManualPreviewDataFiles repeatedImpls repeatedCodeDoc
  let exported := (toJson files.manifest).compress
  let ids := (html.splitOn " id=\"").drop 1 |>.map (fun s => (s.splitOn "\"").head!)
  for (name, ok) in #[
     ("unique rendered ids", ids.eraseDups.length == ids.length),
     ("forward declarations", forward.definedDefs.size == 1 && forward.definedTheorems.size == 1),
     ("reverse declarations", reverse.definedDefs.size == 1 && reverse.definedTheorems.size == 1),
     ("all node badges", countSubstr html "bp_code_link_status_warning" == 3),
     ("no false complete badge", !hasSubstr html "bp_code_link_status_proved"),
     ("exported declarations", #["repeatedForwardClaim", "repeatedForwardHelper",
       "repeatedReverseClaim", "repeatedReverseHelper"].all (hasSubstr exported))] do
    unless ok do throw <| IO.userError s!"Repeated-code regression failed: {name}"
  return true

end Verso.VersoBlueprintTests.BlueprintCodeRenderMatrix

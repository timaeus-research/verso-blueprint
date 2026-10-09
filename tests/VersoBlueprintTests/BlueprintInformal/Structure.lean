/- 
Copyright (c) 2026 Lean FRO LLC. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Author: Emilio J. Gallego Arias
-/

import VersoBlueprintTests.Blueprint.Support
import VersoBlueprintTests.BlueprintInformal.Shared

open Lean
open Verso Genre Manual
open Informal
open Verso.VersoBlueprintTests.Blueprint.Support
open Verso.VersoBlueprintTests.BlueprintInformal.Shared

namespace Verso.VersoBlueprintTests.BlueprintInformal.Structure

private def manualImpls : ExtensionImpls := extension_impls%

/-- error: No registered role `blueprintMissingScopeProbe`. -/
#guard_msgs in
#docs (Manual) failedBodyScopeDoc "Failed Body Scope" :=
:::::::
:::definition "scope.prior"
Previously completed node.
:::

:::definition "scope.failed"
{blueprintMissingScopeProbe}[Invalid body]
:::

:::definition "scope.sibling"
Valid sibling body using {uses "scope.prior"}[].
:::
:::::::

/-- info: true -/
#guard_msgs in
#eval
  show CoreM Bool from do
    let state ← currentState
    pure <| state.activeDirective.isNone &&
      state.data.contains (Name.mkSimple "scope.prior") &&
      !(state.data.contains (Name.mkSimple "scope.failed")) &&
      (state.data.get? (Name.mkSimple "scope.sibling")).any
        (fun node => node.statement.any (fun body => !body.previewBlocks.isEmpty &&
          body.deps.any (fun dep => dep.label == Name.mkSimple "scope.prior")))

elab "failedRetainedBlueprintBodyBlock" : term =>
  throwError "retained Blueprint body failed"

@[code_block]
def failedRetainedBodyProbe : Verso.Doc.Elab.CodeBlockExpanderOf Unit
  | _, _ => `(failedRetainedBlueprintBodyBlock)

-- Preview compilation also reports a generated declaration name, so assert
-- recovery below rather than pinning that unstable secondary diagnostic.
#guard_msgs (drop error) in
#docs (Manual) failedRetainedBodyScopeDoc "Failed Retained Body Scope" :=
:::::::
:::definition "scope.retained.failed"
```failedRetainedBodyProbe
probe
```
:::

:::definition "scope.retained.sibling"
Valid sibling after preview failure.
:::
:::::::

/-- info: true -/
#guard_msgs in
#eval
  show CoreM Bool from do
    let state ← currentState
    pure <| state.activeDirective.isNone &&
      !(state.data.contains (Name.mkSimple "scope.retained.failed")) &&
      (state.data.get? (Name.mkSimple "scope.retained.sibling")).any
        (fun node => node.statement.any (fun body => !body.previewBlocks.isEmpty))

elab "retainedBlueprintBodyBlock" : term => do
  logInfo "retained Blueprint body elaborated"
  Lean.Elab.Term.elabTerm
    (← ``((Verso.Doc.Block.para #[Verso.Doc.Inline.text "Retained body output."] :
      Verso.Doc.Block Verso.Genre.Manual))) none

@[code_block]
def retainedBodyProbe : Verso.Doc.Elab.CodeBlockExpanderOf Unit
  | _, _ => do
    `(retainedBlueprintBodyBlock)

/--
info: retained Blueprint body elaborated
-/
#guard_msgs in
#docs (Manual) retainedBodyDoc "Retained Body" :=
:::::::
:::definition "retained.body"
```retainedBodyProbe
probe
```
:::
:::::::

/-- info: true -/
#guard_msgs in
#eval! do
  let out ← renderManualDocHtmlString manualImpls retainedBodyDoc
  pure <| hasSubstr out "Retained body output."

#docs (Manual) groupHeaderDoc "Group Header" :=
:::::::
:::group "grp.quoted"
A "quoted" heading.
:::
:::::::

/-- info: true -/
#guard_msgs in
#eval
  show CoreM Bool from do
    let state ← currentState
    pure <| state.groups.get? (Name.mkSimple "grp.quoted") == some "A \"quoted\" heading."

/--
error: Label «dup.statement» already defined
-/
#guard_msgs in
#docs (Manual) duplicateStatementRejected "Duplicate Statement Rejected" :=
:::::::
:::definition "dup.statement"
First statement.
:::

:::definition "dup.statement"
Second statement.
:::
:::::::

/-- info: true -/
#guard_msgs in
#eval
  show CoreM Bool from do
    let state ← currentState
    let some node := state.data.get? (Name.mkSimple "dup.statement")
      | return false
    pure (node.statement.isSome && node.proof.isNone)

#docs (Manual) propositionKindDoc "Proposition Kind" :=
:::::::
:::proposition "prop.kind"
Proposition body.
:::
:::::::

/-- info: true -/
#guard_msgs in
#eval
  show CoreM Bool from do
    let state ← currentState
    let some node := state.data.get? (Name.mkSimple "prop.kind")
      | return false
    pure (node.kind == .proposition && node.statement.isSome)

/--
error: Cannot find proof for label «ghost.proof»
-/
#guard_msgs in
#docs (Manual) proofWithoutStatementRejected "Proof Without Statement Rejected" :=
:::::::
:::proof "ghost.proof"
Ghost proof body.
:::
:::::::

/-- info: true -/
#guard_msgs in
#eval
  show CoreM Bool from do
    let state ← currentState
    pure <| !(state.data.contains (Name.mkSimple "ghost.proof"))

end Verso.VersoBlueprintTests.BlueprintInformal.Structure

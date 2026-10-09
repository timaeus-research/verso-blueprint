import VersoBlueprint
import VersoManual

open Verso.Genre Manual Informal

#docs (Manual) proofFoldingDoc "Proof folding" :=
:::::::
:::theorem "folding.internal"
An internal proof argument is part of the statement.
:::

```lean "folding.internal"
theorem internalProofArgument :
    (⟨0, by decide⟩ : Fin 1).val = 0 ∧ True := by
  exact ⟨rfl, trivial⟩

theorem defaultProofArgument (n : Nat := by exact 0) :
    n = n := by
  rfl

theorem termProofWithInternalArgument :
    (⟨0, by decide⟩ : Fin 1).val = 0 := rfl

theorem termBodyWithNestedProof : True := (by trivial)

def visibleDefinition : Nat := by exact 7

theorem nestedBodyProof : True := by
  have h : True := by trivial
  exact h

theorem letInStatement :
    (let n : Nat := (by exact 0); n = n) := by
  rfl

theorem unfoldedLetStatement :
    let n : Nat := 0; n = n := by
  rfl
```
:::::::

def main (args : List String) : IO UInt32 :=
  Informal.PreviewManifest.blueprintMainWithPreviewData
    proofFoldingDoc.toPart args
    (extensionImpls := by exact extension_impls%)

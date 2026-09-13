import VersoBlueprint
import VersoManual

open Verso.Genre Manual Informal

#docs (Manual) termUniversesDoc "Term universes" :=
:::::::
The inline term already supports an explicitly named universe:
{InlineLean.lean (universes := "u")}`fun (α : Type u) (x : α) => x`.

The block must elaborate the same term, without an expected type:

```InlineLean.leanTerm (universes := "u")
fun (α : Type u) (x : α) => x
```

The term and expected type may both mention multiple universes:

```InlineLean.leanTerm (universes := "u v") (type := "(α : Type u) → (β : Type v) → α → β → α × β")
fun (α : Type u) (β : Type v) (x : α) (y : β) => (x, y)
```
:::::::

def main (args : List String) : IO UInt32 :=
  Informal.PreviewManifest.blueprintMainWithPreviewData
    termUniversesDoc.toPart args
    (extensionImpls := by exact extension_impls%)

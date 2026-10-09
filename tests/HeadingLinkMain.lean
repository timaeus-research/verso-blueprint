import VersoBlueprint
import VersoManual

open Verso.Genre Manual Informal

#docs (Manual) headingLinkDoc "Heading links" :=
:::::::
Root introduction.

# Chapter

Chapter introduction.

## Nested

Nested introduction.

### Detail

An unsplit detail.

# Another chapter

## Nested

Repeated heading text in a different chapter.
:::::::

def main (args : List String) : IO UInt32 :=
  Informal.PreviewManifest.blueprintMainWithPreviewData
    headingLinkDoc.toPart args
    (extensionImpls := by exact extension_impls%)

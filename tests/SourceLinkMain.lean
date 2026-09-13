import VersoBlueprint
import VersoManual

open Verso.Genre Manual Informal

#docs (Manual) sourceLinkDoc "Source links" :=
:::::::
:::source_document "paper"
%%%
title := "Source link fixture"
kind := .pdf
pdf := "source/paper.pdf"
%%%
:::

# Chapter

## Nested

:::lemma_ "source.link" (lean := "Nat.add")
%%%
source := {
  document := "paper"
  spans := #[{ page := "5", pdf := some { path := "source/paper.pdf#page=5" } }]
}
%%%
A statement with a site-relative source PDF.
:::
:::::::

def main (args : List String) : IO UInt32 :=
  Informal.PreviewManifest.blueprintMainWithPreviewData
    sourceLinkDoc.toPart args
    (extensionImpls := by exact extension_impls%)

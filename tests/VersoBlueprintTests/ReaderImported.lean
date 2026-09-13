import VersoBlueprint
import VersoManual

open Verso Genre Manual
open Informal

#docs (Manual) importedIdentityDoc "Native paper identity" :=
:::::::
::::definition "identity.imported"
%%%
paperIdentity := some { label := "Definition 2", href := "source/paper.pdf#page=3" }
%%%
An explicitly identified source definition.

:::clarification
The identity belongs to the enclosing definition.
:::
::::

# Nested section

:::lemma_ "identity.nested"
%%%
paperIdentity := some { label := "Lemma 3", href := "https://example.org/paper#lemma-3" }
%%%
A nested source lemma.
:::

:::lemma_ "identity.unnumbered"
%%%
source := { document := "paper", spans := #[{
  page := "3", pdf := some { path := "source/paper.pdf#page=3" } }] }
%%%
An unnumbered intermediate calculation.
:::

:::source_document "paper"
%%%
title := "A source paper"
kind := .pdf
pdf := "source/paper.pdf"
%%%
:::
:::::::

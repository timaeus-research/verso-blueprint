/-
Copyright (c) 2026 Timaeus. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
-/

import VersoBlueprintTests.Blueprint.Support
import VersoBlueprint.BibTeX
import VersoBlueprint.Cite
import VersoBlueprint.Commands.Bibliography

/-!
# BibTeX citations

`blueprint_bibliography_file`, the `{cite}` role, the bibliography part listing the cited BibTeX
entries, and `[KEY, locator]` citations in docstring annotation items.
-/

namespace Verso.VersoBlueprintTests.BlueprintBibtex

open Lean Verso Genre Manual Informal
open Verso.VersoBlueprintTests.Blueprint.Support

private def impls : ExtensionImpls := extension_impls%

/-! ## Processing BibTeX text -/

private def twoKollar : String :=
  "@book{KolA, author = {Kollár, János}, title = {A}, publisher = {P}, year = {2007}}\n" ++
  "@book{KolB, author = {Kollár, János}, title = {B}, publisher = {P}, year = {2007}}\n"

/-- info: ["KolA: Kol07a", "KolB: Kol07b"] -/
#guard_msgs in
#eval
  match BibTeX.process twoKollar with
  | .ok items => items.toList.map fun (i : BibTeX.BibItem) => s!"{i.key}: {i.tag}"
  | .error e => [e]

-- The parser stops silently at a malformed entry; `process` reports it.
/-- info: "malformed BibTeX entry after offset 170: @book{Bad, title = {no closing brace}…" -/
#guard_msgs in
#eval
  match BibTeX.process (twoKollar ++ "@book{Bad, title = {no closing brace}") with
  | .ok items => s!"{items.size} entries"
  | .error e => e

/-- info: "no BibTeX entries" -/
#guard_msgs in
#eval
  match BibTeX.process "% nothing\n" with
  | .ok items => s!"{items.size} entries"
  | .error e => e

/-- info: true -/
#guard_msgs in
#eval
  BibTeX.citationKey "Kol07, Definition 29" == "Kol07" &&
  BibTeX.citationKey "Kol07" == "Kol07" &&
  BibTeX.citationLocator? "Kol07" "Kol07, Definition 29" == some "Definition 29" &&
  BibTeX.citationLocator? "Kol07" "Kol07, Theorem 35 (2), p. 12" == some "Theorem 35 (2), p. 12" &&
  BibTeX.citationLocator? "Kol07" "Kol07, Ch. 0,\n   §1" == some "Ch. 0, §1" &&
  BibTeX.citationLocator? "Kol07" "Kol07" == none &&
  BibTeX.citationLocator? "Kol07" "Hir64, p. 1" == none

/-! ## The registry -/

blueprint_bibliography_file "fixtures/sample.bib"

/-- error: inline BibTeX: the key `Kol07` is already registered -/
#guard_msgs in
blueprint_bibliography_bibtex "@book{Kol07, author = {A}, title = {T}, year = {2007}}"

/-- info: ["Hir64: Hir64", "Kol07: Kol07", "Unc99: NO99", "Sta: TSPA"] -/
#guard_msgs in
#eval show Lean.Elab.Command.CommandElabM _ from do
  pure <| (BibTeX.allItems (← getEnv)).toList.map fun (i : BibTeX.BibItem) => s!"{i.key}: {i.tag}"

-- The entry HTML is escaped; the plain text is not.
/-- info: true -/
#guard_msgs in
#eval show Lean.Elab.Command.CommandElabM Bool from do
  let some item := BibTeX.lookup? (← getEnv) "Unc99" | pure false
  pure <| (item.html.splitOn "&lt;tags&gt; &amp; ampersands").length == 2 &&
    (item.plaintext.splitOn "<tags> & ampersands").length == 2 &&
    (item.html.splitOn "<i>Journal of Nothing</i>").length == 2

/-! ## A document -/

/-- The successor.

Relation to the source.
* **Translation.** `bibSucc n` is $n + 1$ of [Kol07, Definition 29]; see also [Hir64, Ch. 0,
  §1] and the unknown [Nope, Lemma 1].
-/
def bibSucc (n : Nat) : Nat := n + 1

set_option doc.verso true
set_option verso.blueprint.reviewLedger ".lake/bibtex-test-ledger.json"

/-- error: Unknown bibliography key 'Nope' (register the bibliography with blueprint_bibliography_file) -/
#guard_msgs in
#docs (Manual) unknownKeyDoc "Unknown key" :=
:::::::
See {cite Nope}[Lemma 1].
:::::::

#docs (Manual) bibtexDoc "BibTeX citations" :=
:::::::
:::lemma_ "lem:cite"
By {cite Kol07}[Definition 29] and {cite Kol07}[], see {cite Sta}[Tag 01WQ] and
{cite "Hir64"}[Main Theorem I, p. 132].
:::

:::definition "def:succ" (lean := "bibSucc")
The successor.
:::

{blueprint_bibliography}
:::::::

-- Every registered entry with `blueprint_bibliography_all`.
#docs (Manual) bibtexAllDoc "All entries" :=
:::::::
{cite Kol07}[]

{blueprint_bibliography_all}
:::::::

-- Citations: text from the tag, links to the entries, titles, previews, usages; the uncited entry absent.
/-- info: true -/
#guard_msgs in
#eval! show IO Bool from do
  let (html, st) ← renderManualDocHtmlStringAndState impls bibtexDoc
  pure <|
    hasSubstr html "#bp-bib-kol07\" class=\"bp_bibcite\">" &&
    !hasSubstr html "title=\"János Kollár." &&
    hasSubstr html "class=\"bp_bibcite\">[Kol07, Definition 29]</a>" &&
    hasSubstr html "class=\"bp_bibcite\">[Kol07]</a>" &&
    hasSubstr html "#bp-bib-sta\" class=\"bp_bibcite\">" &&
    hasSubstr html "class=\"bp_bibcite\">[TSPA, Tag 01WQ]</a>" &&
    hasSubstr html "class=\"bp_bibcite\">[Hir64, Main Theorem I, p. 132]</a>" &&
    hasSubstr html s!"data-bp-preview-key=\"{Cite.bibCitePreviewKey "Kol07" (some "Definition 29")}\"" &&
    hasSubstr html "data-bp-preview-title=\"[Kol07, Definition 29]\"" &&
    hasSubstr html "<li id=\"bp-bib-kol07\">" &&
    hasSubstr html "<span class=\"bp_bibliography_tag\">[Kol07]</span> János Kollár." &&
    hasSubstr html "<li id=\"bp-bib-sta\">" &&
    hasSubstr html "<li id=\"bp-bib-hir64\">" &&
    !hasSubstr html "bp-bib-unc99" &&
    hasSubstr html "Bibliography (3)" &&
    hasSubstr html "Cited from (3)" &&
    hasSubstr html " - Cites Definition 29" &&
    hasSubstr html " - Cites Tag 01WQ" &&
    (Informal.TraversalIndex.BibtexCitationPreviews.entries st).size == 5

-- A docstring item: `[Kol07, Definition 29]` and `[Hir64, Ch. 0,\n  §1]` link; `[Nope, Lemma 1]` is text.
/-- info: true -/
#guard_msgs in
#eval! show IO Bool from do
  let html ← renderManualDocHtmlString impls bibtexDoc
  pure <|
    countSubstr html "class=\"bp_bibcite\">[Kol07, Definition 29]</a>" == 2 &&
    hasSubstr html "class=\"bp_bibcite\">[Hir64, Ch. 0, §1]</a>" &&
    hasSubstr html "the unknown [Nope, Lemma 1]." &&
    hasSubstr html "Cited from (2)"

/-- info: true -/
#guard_msgs in
#eval! show IO Bool from do
  let html ← renderManualDocHtmlString impls bibtexAllDoc
  pure <|
    hasSubstr html "Bibliography (4)" &&
    hasSubstr html "<li id=\"bp-bib-unc99\">" &&
    hasSubstr html "<span class=\"bp_bibliography_tag\">[NO99]</span>" &&
    hasSubstr html "No citation uses recorded."

end Verso.VersoBlueprintTests.BlueprintBibtex

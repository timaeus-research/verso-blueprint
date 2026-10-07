/-
Copyright (c) 2026 Timaeus. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
-/

import VersoManual
import VersoManual.Markdown
import MD4Lean
import VersoBlueprint.BibTeX
import VersoBlueprint.Cite
import VersoBlueprint.Data
import VersoBlueprint.Editorial
import VersoBlueprint.MarkdownTerms
import VersoBlueprint.SourceRelation

/-!
# Annotation boxes from docstrings

A node's `(lean := "A, B")` declarations may carry a "Relation to the source." section in their
docstrings (`Informal.SourceRelation`). When the node is elaborated, each labelled item becomes an
annotation box of its kind (`Informal.Editorial.Block.sourceItem`), appended to the node's
statement in `(lean := ...)` order and then docstring order; the embedded declaration's plain
docstring display leaves the section out (`Informal.renderDeclHtmlDirectFromInfoE`).

An item's text is Markdown, parsed by MD4Lean with LaTeX math spans and converted to Verso blocks
by `Informal.MarkdownTerms.blockTerm`: inline code becomes `Inline.code`, emphasis
`Inline.emph`/`Inline.bold`, and `$...$` (`$$...$$`) becomes `Inline.math .inline` (`.display`),
which the page renders as it renders `` $`...` `` in the document. A bracketed citation `[KEY]` or
`[KEY, locator]` whose key is in the BibTeX bibliography (`blueprint_bibliography_file`) becomes
the `{cite KEY}[locator]` inline, linked to the entry: the label is given a Markdown reference
definition `[label]: bib:KEY`, and the link that results is converted to the inline. A citation
with its own text, `[Atiyah's Resolution Theorem][Ati70]`, shows that text, linked the same way.
-/

register_option verso.blueprint.reviewLedger : String := {
  defValue := "reviews.json"
  descr := "Review ledger for the annotations taken from docstrings (a JSON array of " ++
    "{decl, kind, hash, reviewer, date}), relative to the directory the blueprint is generated " ++
    "from (the package root under `lake exe vbp build`); a missing file means every such " ++
    "annotation is unreviewed"
}

namespace Informal.SourceAnnotations

open Lean Elab
open Verso Doc Elab

/-- MD4Lean parser flags for an item: CommonMark, LaTeX math spans, no raw HTML. -/
def markdownFlags : UInt32 :=
  MD4Lean.MD_DIALECT_COMMONMARK ||| MD4Lean.MD_FLAG_LATEXMATHSPANS ||| MD4Lean.MD_FLAG_NOHTML

/-- The Verso blocks of an item's Markdown text; the plain text when it cannot be converted. -/
def itemBlocks (ref : Syntax) (decl : Name) (markdown : String) : DocElabM (Array Term) := do
  let plain : DocElabM (Array Term) := do
    pure #[← ``(Verso.Doc.Block.para #[Verso.Doc.Inline.text $(quote markdown)])]
  let env ← getEnv
  let citations := Informal.BibTeX.findCitations env markdown
  -- A reference definition per citation label makes `[KEY, locator]` a link to `bib:KEY`.
  let definitions := String.join <| citations.toList.map fun (label, item) =>
    s!"[{label}]: bib:{item.key}\n"
  let text := if citations.isEmpty then markdown else markdown ++ "\n\n" ++ definitions
  let some doc := MD4Lean.parse text markdownFlags
    | logWarningAt ref m!"{decl}: an item of the \"{SourceRelation.heading}\" section is not valid Markdown; shown as plain text"
      plain
  let onLink (href : String) (contents : Array MD4Lean.Text) : DocElabM (Option Term) := do
    let some key := href.dropPrefix? "bib:" |>.map (·.toString) | pure none
    let some item := Informal.BibTeX.lookup? env key | pure none
    let label := Informal.MarkdownTerms.textsToPlain contents
    if Informal.BibTeX.citationKey label == item.key then
      -- `[KEY]` or `[KEY, locator]`
      some <$> Informal.mkBibCiteTerm item (Informal.BibTeX.citationLocator? item.key label)
    else
      -- `[text][KEY]`: the text is shown, linked to the entry
      some <$> Informal.mkBibCiteTerm item none (some label)
  try
    doc.blocks.mapM fun b => Informal.MarkdownTerms.blockTerm onLink b
  catch e =>
    logWarningAt ref m!"{decl}: an item of the \"{SourceRelation.heading}\" section cannot be rendered ({e.toMessageData}); shown as plain text"
    plain

/--
The annotation boxes of the "Relation to the source." items in the docstrings of `refs`, the
declarations a node embeds. Problems in a section (an unlabelled bullet, an unknown label) are
warnings at `ref`, the node's label, one for each declaration and distinct problem (two identical
bad bullets give one warning). When the node embeds several declarations, each box names its
declaration. Each box carries the hashes of all items of its label in its declaration's docstring,
which the review status needs (`Informal.ReviewLedger.status`).
-/
def termsForRefs (ref : Syntax) (refs : Array Data.ExternalRef) : DocElabM (Array Term) := do
  let ledger := verso.blueprint.reviewLedger.get (← getOptions)
  let several := refs.size > 1
  let env ← getEnv
  let mut out : Array Term := #[]
  let mut warned : Std.HashSet (Name × String) := {}
  for extRef in refs do
    unless extRef.present do continue
    let decl := extRef.canonical
    let some docs ← (findDocString? env decl : IO _) | continue
    let parsed := SourceRelation.parse docs
    for problem in parsed.problems do
      let msg := problem.message
      unless warned.contains (decl, msg) do
        warned := warned.insert (decl, msg)
        logWarningAt ref m!"{decl}: {msg}"
    let declLabel := if several then extRef.displayName.toString else ""
    for h : i in [0:parsed.items.size] do
      let item := parsed.items[i]
      -- the hashes of the items with this label, in docstring order, and this item's position
      let siblings := parsed.items.filter (·.label == item.label) |>.map (·.hash)
      let index := (parsed.items.extract 0 i).filter (·.label == item.label) |>.size
      let blocks ← itemBlocks ref decl item.markdown
      out := out.push (← ``(Verso.Doc.Block.other
        (Informal.Editorial.Block.sourceItem $(quote item.label.kindKey) $(quote item.label.text)
          $(quote decl.toString) $(quote declLabel) $(quote item.hash) $(quote siblings)
          $(quote index) $(quote ledger))
        #[$blocks,*]))
  return out

end Informal.SourceAnnotations

/-
Copyright (c) 2026 Timaeus. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
-/

import VersoManual
import VersoManual.Markdown
import MD4Lean
import VersoBlueprint.Data
import VersoBlueprint.Editorial
import VersoBlueprint.SourceRelation

/-!
# Annotation boxes from docstrings

A node's `(lean := "A, B")` declarations may carry a "Relation to the source." section in their
docstrings (`Informal.SourceRelation`). When the node is elaborated, each labelled item becomes an
annotation box of its kind (`Informal.Editorial.Block.sourceItem`), appended to the node's
statement in `(lean := ...)` order and then docstring order; the embedded declaration's plain
docstring display leaves the section out (`Informal.renderDeclHtmlDirectFromInfoE`).

An item's text is Markdown, parsed by MD4Lean with LaTeX math spans and converted to Verso blocks
by `Verso.Genre.Manual.Markdown.blockFromMarkdown`: inline code becomes `Inline.code`, emphasis
`Inline.emph`/`Inline.bold`, and `$...$` (`$$...$$`) becomes `Inline.math .inline` (`.display`),
which the page renders as it renders `` $`...` `` in the document.
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
  let some doc := MD4Lean.parse markdown markdownFlags
    | logWarningAt ref m!"{decl}: an item of the \"{SourceRelation.heading}\" section is not valid Markdown; shown as plain text"
      plain
  try
    doc.blocks.mapM fun b =>
      Verso.Genre.Manual.Markdown.blockFromMarkdown b
        (handleHeaders := Verso.Genre.Manual.Markdown.strongEmphHeaders)
  catch e =>
    logWarningAt ref m!"{decl}: an item of the \"{SourceRelation.heading}\" section cannot be rendered ({e.toMessageData}); shown as plain text"
    plain

/--
The annotation boxes of the "Relation to the source." items in the docstrings of `refs`, the
declarations a node embeds. Problems in a section (an unlabelled bullet, an unknown label) are
warnings at `ref`, the node's label. When the node embeds several declarations, each box names its
declaration.
-/
def termsForRefs (ref : Syntax) (refs : Array Data.ExternalRef) : DocElabM (Array Term) := do
  let ledger := verso.blueprint.reviewLedger.get (← getOptions)
  let several := refs.size > 1
  let env ← getEnv
  let mut out : Array Term := #[]
  for extRef in refs do
    unless extRef.present do continue
    let decl := extRef.canonical
    let some docs ← (findDocString? env decl : IO _) | continue
    let parsed := SourceRelation.parse docs
    for problem in parsed.problems do
      logWarningAt ref m!"{decl}: {problem.message}"
    let declLabel := if several then extRef.displayName.toString else ""
    for item in parsed.items do
      let blocks ← itemBlocks ref decl item.markdown
      out := out.push (← ``(Verso.Doc.Block.other
        (Informal.Editorial.Block.sourceItem $(quote item.label.kindKey) $(quote item.label.text)
          $(quote decl.toString) $(quote declLabel) $(quote item.hash) $(quote ledger))
        #[$blocks,*]))
  return out

end Informal.SourceAnnotations

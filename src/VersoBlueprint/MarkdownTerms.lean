/-
Copyright (c) 2026 Timaeus. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
-/

import Lean
import MD4Lean
import VersoManual
import VersoManual.Markdown

/-!
# Markdown to Verso terms, with a hook for links

`Verso.Genre.Manual.Markdown.blockFromMarkdown` converts parsed Markdown to the syntax of Verso
blocks, with no way to treat a link specially. This module is that conversion (the cases
`VersoBlueprint` needs: paragraphs, lists, block quotes, code, emphasis, links, math) with a hook
`onLink`, consulted for each link before the default `Inline.link`: the annotation boxes from
docstrings (`VersoBlueprint.SourceAnnotations`) turn the links `bib:KEY` of bracketed citations
into `{cite}` inlines. Headers are handled as `strongEmphHeaders` does: bold, then emphasis.
-/

open Lean
open Verso Doc Elab

namespace Informal.MarkdownTerms

/-- The text of inline Markdown, for a link's content: text and line breaks as written, code and
math as their source, emphasis dropped. -/
partial def textsToPlain (ts : Array MD4Lean.Text) : String :=
  ts.foldl (init := "") fun acc t => acc ++ textToPlain t
where
  textToPlain : MD4Lean.Text → String
    | .normal s | .br s | .softbr s => s
    | .em ts | .strong ts | .u ts | .del ts | .a _ _ _ ts | .wikiLink _ ts => textsToPlain ts
    | .code strs | .latexMath strs | .latexMathDisplay strs => String.join strs.toList
    | .img _ _ alt => textsToPlain alt
    | .entity e => e
    | .nullchar => ""

private def attrText : MD4Lean.AttrText → Except String String
  | .normal str => pure str
  | .nullchar => throw "Null character"
  | .entity ent => throw s!"Unsupported entity {ent}"

/-- The text of a link's attribute. -/
def attr (val : Array MD4Lean.AttrText) : DocElabM String :=
  match val.mapM attrText |>.map Array.toList |>.map String.join with
  | .error e => throwError e
  | .ok s => pure s

/-- The term of inline Markdown. `onLink href contents` may give the term of a link; otherwise
it is `Inline.link`. -/
partial def inlineTerm (onLink : String → Array MD4Lean.Text → DocElabM (Option Term)) :
    MD4Lean.Text → DocElabM Term
  | .normal str | .br str | .softbr str => ``(Verso.Doc.Inline.text $(quote str))
  | .nullchar => throwError "Unexpected null character in parsed Markdown"
  | .del _ => throwError "Unexpected strikethrough in parsed Markdown"
  | .em txt => do ``(Verso.Doc.Inline.emph #[$[$(← txt.mapM (inlineTerm onLink))],*])
  | .strong txt => do ``(Verso.Doc.Inline.bold #[$[$(← txt.mapM (inlineTerm onLink))],*])
  | .a href _ _ txt => do
    let href ← attr href
    if let some t ← onLink href txt then
      pure t
    else
      ``(Verso.Doc.Inline.link #[$[$(← txt.mapM (inlineTerm onLink))],*] $(quote href))
  | .latexMath m =>
    ``(Verso.Doc.Inline.math Verso.Doc.MathMode.inline $(quote <| String.join m.toList))
  | .latexMathDisplay m =>
    ``(Verso.Doc.Inline.math Verso.Doc.MathMode.display $(quote <| String.join m.toList))
  | .u txt => throwError "Unexpected underline around {repr txt} in parsed Markdown"
  | .code strs => ``(Verso.Doc.Inline.code $(quote (String.join strs.toList)))
  | .entity ent => throwError s!"Unsupported entity {ent} in parsed Markdown"
  | .img .. => throwError s!"Unexpected image in parsed Markdown"
  | .wikiLink .. => throwError s!"Unexpected wiki-style link in parsed Markdown"

/-- The term of a Markdown block. A header of level 1 is a bold paragraph, of level 2 an
emphasised one, as `Verso.Genre.Manual.Markdown.strongEmphHeaders`. -/
partial def blockTerm (onLink : String → Array MD4Lean.Text → DocElabM (Option Term)) :
    MD4Lean.Block → DocElabM Term
  | .p txt => do ``(Verso.Doc.Block.para #[$[$(← txt.mapM (inlineTerm onLink))],*])
  | .blockquote bs => do ``(Verso.Doc.Block.blockquote #[$[$(← bs.mapM (blockTerm onLink))],*])
  | .code _ _ _ strs => ``(Verso.Doc.Block.code $(quote (String.join strs.toList)))
  | .ul _ _ items => do ``(Verso.Doc.Block.ul #[$[$(← items.mapM (itemTerm onLink))],*])
  | .ol _ i _ items => do
    let itemStx ← items.mapM (itemTerm onLink)
    ``(Verso.Doc.Block.ol (Int.ofNat $(quote i)) #[$itemStx,*])
  | .header level txt => do
    let inlines ← txt.mapM (inlineTerm onLink)
    match level with
    | 1 => ``(Verso.Doc.Block.para #[Verso.Doc.Inline.bold #[$inlines,*]])
    | 2 => ``(Verso.Doc.Block.para #[Verso.Doc.Inline.emph #[$inlines,*]])
    | _ => throwError "Unexpected header of level {level} in parsed Markdown"
  | .html .. => throwError "Unexpected literal HTML in parsed Markdown"
  | .hr => throwError "Unexpected horizontal rule (thematic break) in parsed Markdown"
  | .table .. => throwError "Unexpected table in parsed Markdown"
where
  itemTerm (onLink : String → Array MD4Lean.Text → DocElabM (Option Term))
      (item : MD4Lean.Li MD4Lean.Block) : DocElabM Term := do
    if item.isTask then throwError "Tasks unsupported"
    else ``(Verso.Doc.ListItem.mk #[$[$(← item.contents.mapM (blockTerm onLink))],*])

end Informal.MarkdownTerms

/-
Copyright (c) 2026 Timaeus. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
-/

import Lean
import MD4Lean
import Verso
import VersoBlueprint.BibTeX

/-!
# A docstring as HTML

The docstring of an embedded declaration (`VersoBlueprint.ExternalDeclRender`) is Markdown. `render?`
turns it into HTML directly, without the Verso document model, since it is rendered when the
declaration is rendered: paragraphs, lists, block quotes, code, emphasis, links and `$...$` math
(as the page renders Verso's math, in `<code class="math inline">`). A bracketed citation `[KEY]`
or `[KEY, locator]` whose key is in the BibTeX bibliography (`blueprint_bibliography_file`), or a
citation with its own text `[text][KEY]`, becomes the HTML that `cite` gives for the entry and the
text, which the caller links to the bibliography (`Informal.ExternalDeclRender`). Markdown that this
does not handle (tables, raw HTML, a thematic break) gives `none`, and the caller shows the
docstring as it is.
-/

open Lean Verso.Output Verso.Output.Html

namespace Informal.DocstringHtml

/-- MD4Lean parser flags for a docstring: CommonMark, LaTeX math spans, no raw HTML. -/
def markdownFlags : UInt32 :=
  MD4Lean.MD_DIALECT_COMMONMARK ||| MD4Lean.MD_FLAG_LATEXMATHSPANS ||| MD4Lean.MD_FLAG_NOHTML

/-- The text of a Markdown attribute. -/
private def attrText (val : Array MD4Lean.AttrText) : Option String :=
  val.foldlM (init := "") fun acc t =>
    match t with
    | .normal s => some (acc ++ s)
    | .entity _ | .nullchar => none

/-- The text of inline Markdown, for a citation's content. -/
private partial def textsToPlain (ts : Array MD4Lean.Text) : String :=
  ts.foldl (init := "") fun acc t => acc ++ textToPlain t
where
  textToPlain : MD4Lean.Text → String
    | .normal s | .br s | .softbr s => s
    | .em ts | .strong ts | .u ts | .del ts | .a _ _ _ ts | .wikiLink _ ts => textsToPlain ts
    | .code strs | .latexMath strs | .latexMathDisplay strs => String.join strs.toList
    | .img _ _ alt => textsToPlain alt
    | .entity e => e
    | .nullchar => ""

/-- The HTML of a citation link of the entry `item` with the Markdown link's content `label`
(`"Kol07, Definition 29"`, or the text of `[text][KEY]`): `cite item text`, where `text` is what
the link shows. -/
private def citationHtml (cite : Informal.BibTeX.BibItem → String → Html)
    (item : Informal.BibTeX.BibItem) (label : String) : Html :=
  if Informal.BibTeX.citationKey label == item.key then
    match Informal.BibTeX.citationLocator? item.key label with
    | some locator => cite item s!"[{item.tag}, {locator}]"
    | none => cite item s!"[{item.tag}]"
  else
    cite item (Informal.BibTeX.normalizeLocator label)

private partial def inlineHtml (env : Environment) (cite : Informal.BibTeX.BibItem → String → Html) :
    MD4Lean.Text → Option Html
  | .normal s | .br s | .softbr s => some (.text true s)
  | .nullchar => none
  | .del ts => inlines ts |>.map fun h => {{<del>{{h}}</del>}}
  | .u ts => inlines ts |>.map fun h => {{<u>{{h}}</u>}}
  | .em ts => inlines ts |>.map fun h => {{<em>{{h}}</em>}}
  | .strong ts => inlines ts |>.map fun h => {{<strong>{{h}}</strong>}}
  | .a href _ _ ts => do
    let href ← attrText href
    if let some key := href.dropPrefix? "bib:" then
      let some item := Informal.BibTeX.lookup? env key.toString | none
      some (citationHtml cite item (textsToPlain ts))
    else
      let h ← inlines ts
      some {{<a href={{href}}>{{h}}</a>}}
  | .latexMath m => some {{<code class="math inline">{{.text true (String.join m.toList)}}</code>}}
  | .latexMathDisplay m =>
    some {{<code class="math display">{{.text true (String.join m.toList)}}</code>}}
  | .code strs => some {{<code>{{.text true (String.join strs.toList)}}</code>}}
  | .entity _ | .img .. | .wikiLink .. => none
where
  inlines (ts : Array MD4Lean.Text) : Option Html :=
    ts.foldlM (init := Html.empty) fun acc t => (acc ++ ·) <$> inlineHtml env cite t

private partial def blockHtml (env : Environment) (cite : Informal.BibTeX.BibItem → String → Html) :
    MD4Lean.Block → Option Html
  | .p ts => inlines ts |>.map fun h => {{<p>{{h}}</p>}}
  | .blockquote bs => blocks bs |>.map fun h => {{<blockquote>{{h}}</blockquote>}}
  | .code _ _ _ strs => some {{<pre><code>{{.text true (String.join strs.toList)}}</code></pre>}}
  | .ul _ _ items => items.mapM item |>.map fun hs => {{<ul>{{hs}}</ul>}}
  | .ol _ start _ items => items.mapM item |>.map fun hs =>
    if start == 1 then {{<ol>{{hs}}</ol>}} else {{<ol start={{toString start}}>{{hs}}</ol>}}
  | .header level ts => inlines ts |>.map fun h =>
    match level with
    | 1 => {{<p><strong>{{h}}</strong></p>}}
    | _ => {{<p><em>{{h}}</em></p>}}
  | .hr | .html .. | .table .. => none
where
  inlines (ts : Array MD4Lean.Text) : Option Html :=
    ts.foldlM (init := Html.empty) fun acc t => (acc ++ ·) <$> inlineHtml env cite t
  blocks (bs : Array MD4Lean.Block) : Option Html :=
    bs.foldlM (init := Html.empty) fun acc b => (acc ++ ·) <$> blockHtml env cite b
  item (li : MD4Lean.Li MD4Lean.Block) : Option Html :=
    if li.isTask then none else blocks li.contents |>.map fun h => {{<li>{{h}}</li>}}

/--
The HTML of the Markdown `docs`, with the bracketed citations of registered BibTeX entries
rendered by `cite` (given the entry and the text to show); `none` when `docs` is not Markdown this
renders.
-/
def render? (env : Environment) (docs : String)
    (cite : Informal.BibTeX.BibItem → String → Html) : Option Html := do
  let citations := Informal.BibTeX.findCitations env docs
  -- A reference definition per citation label makes `[KEY, locator]` a link to `bib:KEY`.
  let definitions := String.join <| citations.toList.map fun (label, item) =>
    s!"[{label}]: bib:{item.key}\n"
  let text := if citations.isEmpty then docs else docs ++ "\n\n" ++ definitions
  let doc ← MD4Lean.parse text markdownFlags
  doc.blocks.foldlM (init := Html.empty) fun acc b => (acc ++ ·) <$> blockHtml env cite b

end Informal.DocstringHtml

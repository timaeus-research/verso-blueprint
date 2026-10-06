/-
Copyright (c) 2026 Lean FRO LLC. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Author: Emilio J. Gallego Arias
-/

import Lean
import Verso
import VersoManual
import VersoBlueprint.BibTeX
import VersoBlueprint.DocstringHtml
import VersoBlueprint.Lib.HtmlId
import VersoBlueprint.SourceRelation

open Lean Meta

register_option verso.blueprint.externalCode.definitionBodies : Bool := {
  defValue := true
  descr := "Show the body of a plain definition (not a theorem, instance, structure or inductive) " ++
    "after its signature when rendering an external Lean declaration"
}

register_option verso.blueprint.externalCode.showUniverses : Bool := {
  defValue := false
  descr := "Show the universe parameter list (`.{u_1, u_2}`) after the name of an external Lean " ++
    "declaration"
}

register_option verso.blueprint.externalCode.docsBaseUrl : String := {
  defValue := "https://leanprover-community.github.io/mathlib4_docs/"
  descr := "Base URL of the published API documentation that constants of Lean core, Std, Lake, " ++
    "Mathlib and Mathlib's dependencies link to when no blueprint node presents them; empty " ++
    "disables these links"
}

namespace Informal

/--
`n` relative to the open namespaces: the longest open namespace that is a proper prefix of `n` is
dropped, so that the name reads as it would in a file with those `open`s (`GreyBook.LearningSetup.Kn`
under `open GreyBook` is `LearningSetup.Kn`).
-/
def shortenName (opens : List Name) (n : Name) : Name :=
  let candidates := opens.filter fun ns => ns.isPrefixOf n && ns != n
  match candidates.foldl (fun best ns =>
      match best with
      | none => some ns
      | some b => if ns.getNumParts > b.getNumParts then some ns else some b) none with
  | some ns => n.replacePrefix ns .anonymous
  | none => n


abbrev ExternalDeclHtml := Verso.Output.Html

/-! ## Declaration links

A constant in rendered declaration code links to the blueprint node that presents it. Which node
that is becomes known only when the whole document has been traversed, long after the declaration
was rendered (at elaboration of its chapter), so the rendered HTML carries a marker around each
constant token and the page renderer resolves the markers (`rewriteDeclLinks`). The token is
preceded by the HTML comment `bp-decl:NAME|DOCS` and followed by the comment `/bp-decl`.
`NAME` is the constant's full name and `DOCS` the URL of its entry in the published API
documentation, or empty (both with `%`, `-`, `>` and `|` percent-encoded). A marker whose name
resolves to a node becomes a link to that node's rendering of the declaration; otherwise one with
a documentation URL links there; otherwise the marker is dropped and the token keeps only its hover.
-/

/-- Module roots documented at `verso.blueprint.externalCode.docsBaseUrl` (Mathlib's API docs). -/
def docsModuleRoots : List Name :=
  [`Init, `Std, `Lean, `Lake, `Mathlib, `Batteries, `Aesop, `Qq, `ProofWidgets, `Plausible,
    `ImportGraph, `LeanSearchClient]

/--
The URL of `decl` in the published API documentation at `baseUrl` (doc-gen4 layout: one page per
module, the declaration's full name as anchor), when `decl` is a public constant of a module under
one of `docsModuleRoots` and not an auxiliary recursor (which doc-gen4 does not document).

The published documentation follows Mathlib's master branch, not the Mathlib a project pins, so a
declaration that has since moved to another module or been renamed gets a link to a page without
its anchor, or to no page.
-/
def docsHref? (env : Environment) (baseUrl : String) (decl : Name) : Option String := do
  if baseUrl.isEmpty || decl.isInternal || isPrivateName decl || isAuxRecursor env decl ||
      isNoConfusion env decl then none
  let idx ← env.getModuleIdxFor? decl
  let mod ← env.header.moduleNames[idx.toNat]?
  unless docsModuleRoots.contains mod.getRoot do none
  let base := if baseUrl.endsWith "/" then baseUrl else baseUrl ++ "/"
  let path := "/".intercalate (mod.components.map (·.toString (escape := false)))
  some s!"{base}{path}.html#{decl}"

private def declMarkerEncode (s : String) : String :=
  s.replace "%" "%25" |>.replace "-" "%2D" |>.replace ">" "%3E" |>.replace "|" "%7C"

private def declMarkerDecode (s : String) : String :=
  s.replace "%7C" "|" |>.replace "%3E" ">" |>.replace "%2D" "-" |>.replace "%25" "%"

private def declMarkerOpenPrefix : String := "<!--bp-decl:"
private def declMarkerClose : String := "<!--/bp-decl-->"
private def declLinkPlaceholderPrefix : String := "bp-decl:"

private def escapeHtmlAttr (s : String) : String :=
  s.replace "&" "&amp;" |>.replace "\"" "&quot;" |>.replace "<" "&lt;" |>.replace ">" "&gt;"

/--
Resolve the declaration-link markers of rendered declaration HTML. `declHref` maps a constant's
full name (`Name.toString`) to the page link of the node presenting it.
-/
def rewriteDeclLinks (html : String) (declHref : String → Option String) : String :=
  match html.splitOn declMarkerOpenPrefix with
  | [] => html
  | first :: rest =>
    rest.foldl (init := first) fun out part =>
      match part.splitOn "-->" with
      | header :: afterHeader =>
        let body := "-->".intercalate afterHeader
        let (name, docs) :=
          match header.splitOn "|" with
          | [n, d] => (declMarkerDecode n, declMarkerDecode d)
          | _ => (declMarkerDecode header, "")
        let linkClass := if name.startsWith "bib:" then "bp_bibcite" else "bp_decl_link"
        let href? : Option (String × String) :=
          match declHref name with
          | some href => some (href, linkClass)
          | none => if docs.isEmpty then none else some (docs, "bp_decl_link bp_decl_link_docs")
        let (openTag, closeTag) :=
          match href? with
          | some (href, cls) => (s!"<a class=\"{cls}\" href=\"{escapeHtmlAttr href}\">", "</a>")
          | none => ("", "")
        let body :=
          match body.splitOn declMarkerClose with
          | [] => body
          | inner :: after => inner ++ closeTag ++ declMarkerClose.intercalate after
        out ++ openTag ++ body
      | [] => out ++ part

/-- Link targets that mark every constant token (see `rewriteDeclLinks`). -/
private def declLinkTargets (env : Environment) (docsBaseUrl : String) :
    Verso.Code.LinkTargets Verso.Genre.Manual.TraverseContext where
  const n _ :=
    #[{ shortDescription := "decl"
        description := (docsHref? env docsBaseUrl n).getD ""
        href := declLinkPlaceholderPrefix ++ n.toString }]

inductive ExternalDeclRenderError where
  | moduleUnavailable (decl : Name)
  | exception (decl : Name) (message : String)
  deriving Repr, Inhabited, Lean.ToJson, Lean.FromJson, Lean.Quote

def ExternalDeclRenderError.message : ExternalDeclRenderError → String
  | .moduleUnavailable decl => s!"module unavailable for {decl}"
  | .exception decl message => s!"{decl}: {message}"

/--
One hover payload captured while rendering an external declaration snippet.

External declarations are rendered before the final page `Html.State` exists, so
their highlighted-code hovers cannot be inserted into Verso's page hover table
immediately. Each payload records the snippet-local id plus the hover body that
the page renderer can later deduplicate against all other page hovers.
-/
structure ExternalDeclHoverPayload where
  localId : Nat
  html : String
deriving Repr, Inhabited, Lean.ToJson, Lean.FromJson, Lean.Quote

/--
Rendered external declaration HTML in both forms needed by Blueprint.

`html` is a compact template: it uses Blueprint-local hover ids, carries hover
bodies separately in `hoverPayloads`, and contains a tiny marker where the
standalone hover body should be reinserted. The final page and generated-cache
renderers rewrite the local ids into Verso hover ids and remove the markers;
isolated preview paths inline the payloads at the markers to recover standalone
HTML.

The local ids in `html` are not stable semantic ids. They are only positions in
the isolated highlighted-code hover table produced while rendering this snippet.
The page renderer must therefore translate them before emitting normal
`data-verso-hover` attributes.
-/
structure ExternalDeclRenderedHtml where
  html : String
  hoverPayloads : Array ExternalDeclHoverPayload
deriving Repr, Inhabited, Lean.ToJson, Lean.FromJson, Lean.Quote

def externalDeclHoverLocalAttrName : String := "data-bp-external-hover-local"

def externalDeclHoverInlineMarkerAttrName : String := "data-bp-external-hover-inline-local"

/--
Replacement pair for one snippet-local external-declaration hover id.
-/
structure ExternalDeclHoverRewrite where
  localId : Nat
  attrReplacement : String
  inlineReplacement : String
deriving Repr, Inhabited

private def externalDeclHoverLocalAttrPrefix : String :=
  s!"{externalDeclHoverLocalAttrName}=\""

private def externalDeclHoverInlineMarkerPrefix : String :=
  s!"<span {externalDeclHoverInlineMarkerAttrName}=\""

private def externalDeclHoverInlineMarkerSuffix : String :=
  "></span>"

private def externalDeclHoverMarkerNamePrefix : String :=
  "data-bp-external-hover-"

private inductive ExternalDeclHoverMarkerKind where
  | attr
  | inline

private def findExternalDeclHoverRewrite?
    (rewrites : Array ExternalDeclHoverRewrite) (localId : Nat) :
    Option ExternalDeclHoverRewrite :=
  rewrites.find? (fun rewrite => rewrite.localId == localId)

private def parseExternalDeclHoverMarker?
    (html : String) (markerPrefix : String) (start : html.Pos) :
    Option (Nat × html.Pos) := do
  let idStart := start.nextn markerPrefix.length
  let quotePos ← idStart.find? "\""
  let localId ← (html.extract idStart quotePos).toNat?
  let afterQuote ← quotePos.next?
  some (localId, afterQuote)

private def parseExternalDeclHoverInlineMarker?
    (html : String) (start : html.Pos) : Option (Nat × html.Pos) := do
  let (localId, afterQuote) ←
    parseExternalDeclHoverMarker? html externalDeclHoverInlineMarkerPrefix start
  let markerEnd := afterQuote.nextn externalDeclHoverInlineMarkerSuffix.length
  if html.extract afterQuote markerEnd == externalDeclHoverInlineMarkerSuffix then
    some (localId, markerEnd)
  else
    none

private partial def findNextExternalDeclHoverMarker?
    (html : String) (pos : html.Pos) :
    Option (ExternalDeclHoverMarkerKind × html.Pos) := do
  let markerNamePos ← pos.find? externalDeclHoverMarkerNamePrefix
  if (html.sliceFrom markerNamePos).startsWith externalDeclHoverLocalAttrPrefix then
    some (.attr, markerNamePos)
  else
    let inlinePos := markerNamePos.prevn "<span ".length
    if (html.sliceFrom inlinePos).startsWith externalDeclHoverInlineMarkerPrefix then
      some (.inline, inlinePos)
    else
      markerNamePos.next?.bind (findNextExternalDeclHoverMarker? html)

private partial def rewriteExternalDeclHoverTemplateLoop
    (html : String)
    (rewrites : Array ExternalDeclHoverRewrite)
    (pos : html.Pos)
    (parts : Array String) : Array String :=
  match findNextExternalDeclHoverMarker? html pos with
  | none =>
      parts.push (html.extract pos html.endPos)
  | some (kind, markerPos) =>
      let parts := parts.push (html.extract pos markerPos)
      let fallback : Unit → Array String := fun _ =>
        match markerPos.next? with
        | some nextPos =>
            rewriteExternalDeclHoverTemplateLoop html rewrites nextPos
              (parts.push (html.extract markerPos nextPos))
        | none =>
            parts.push (html.extract markerPos html.endPos)
      let parsed? :=
        match kind with
        | .attr =>
            parseExternalDeclHoverMarker? html externalDeclHoverLocalAttrPrefix markerPos
        | .inline =>
            parseExternalDeclHoverInlineMarker? html markerPos
      match parsed? with
      | none => fallback ()
      | some (localId, nextPos) =>
          match findExternalDeclHoverRewrite? rewrites localId with
          | none => fallback ()
          | some rewrite =>
              let replacement :=
                match kind with
                | .attr => rewrite.attrReplacement
                | .inline => rewrite.inlineReplacement
              let parts :=
                if replacement.isEmpty then parts else parts.push replacement
              rewriteExternalDeclHoverTemplateLoop html rewrites nextPos parts

/--
The page form of the template: hover ids rewritten by `rewrites`, declaration-link markers resolved
by `declHref` (see `rewriteDeclLinks`).
-/
def ExternalDeclRenderedHtml.rewriteHovers
    (rendered : ExternalDeclRenderedHtml)
    (rewrites : Array ExternalDeclHoverRewrite)
    (declHref : String → Option String := fun _ => none) : String :=
  let html := rewriteDeclLinks rendered.html declHref
  String.join <|
    (rewriteExternalDeclHoverTemplateLoop html rewrites html.startPos #[]).toList

def ExternalDeclRenderedHtml.selfContained (rendered : ExternalDeclRenderedHtml)
    (declHref : String → Option String := fun _ => none) : String :=
  rendered.rewriteHovers (declHref := declHref) <|
    rendered.hoverPayloads.map fun payload => {
      localId := payload.localId
      attrReplacement := ""
      inlineReplacement := s!"<span class=\"hover-info\">{payload.html}</span>"
    }

abbrev ExternalDeclRenderResult := Except ExternalDeclRenderError ExternalDeclRenderedHtml

private abbrev ExternalDeclHighlightRender :=
  ReaderT (Verso.Code.HighlightHtmlM.Context Verso.Genre.Manual)
    (StateT (Verso.Code.Hover.State ExternalDeclHtml) Id)

private def highlightedHtmlContext (env : Environment) (docsBaseUrl : String) :
    Verso.Code.HighlightHtmlM.Context Verso.Genre.Manual := {
  linkTargets := declLinkTargets env docsBaseUrl
  traverseContext := {}
  definitionIds := {}
  options := {}
}

private def runHighlightedHtml
    (html : Verso.Code.HighlightHtmlM Verso.Genre.Manual ExternalDeclHtml) :
    ExternalDeclHighlightRender ExternalDeclHtml := do
  let ctx ← read
  let hoverState ← get
  let (html, hoverState) := ((html.run ctx).run hoverState)
  set hoverState
  pure html

private def templateVersoHoverAttrs
    (html : ExternalDeclHtml) (hoverDedup : Verso.Code.Hover.Dedup ExternalDeclHtml) :
    ExternalDeclHtml :=
  Id.run <|
    html.visitM (tag := fun name attrs contents => do
      let mut marker? : Option Nat := none
      let mut attrs' : Array (String × String) := #[]
      for attr in attrs do
        match attr with
        | ("data-verso-hover", value) =>
            match value.toNat? with
            | some localId =>
                if (hoverDedup.get? localId).isSome then
                  marker? := some localId
                  attrs' := attrs'.push (externalDeclHoverLocalAttrName, value)
                else
                  attrs' := attrs'.push attr
            | none => attrs' := attrs'.push attr
        | attr => attrs' := attrs'.push attr
      let contents :=
        match marker? with
        | some localId =>
            contents ++ .tag "span" #[(externalDeclHoverInlineMarkerAttrName, toString localId)] .empty
        | none => contents
      -- A constant's placeholder link (`declLinkTargets`) becomes a declaration-link marker.
      if name == "a" then
        if let some href := attrs.find? (·.1 == "href") |>.map (·.2) then
          if href.startsWith declLinkPlaceholderPrefix then
            let decl := (href.drop declLinkPlaceholderPrefix.length).toString
            let docs := (attrs.find? (·.1 == "title") |>.map (·.2)).getD ""
            let header :=
              s!"{declMarkerOpenPrefix}{declMarkerEncode decl}|{declMarkerEncode docs}-->"
            return some <| .seq #[.text false header, contents, .text false declMarkerClose]
      pure <| some <| .tag name attrs' contents)

private def hoverPayloads
    (hoverDedup : Verso.Code.Hover.Dedup ExternalDeclHtml) : Array ExternalDeclHoverPayload :=
  hoverDedup.contentId.fold (init := #[]) (fun out localId html =>
    out.push { localId, html := html.asString })
  |>.qsort (fun a b => a.localId < b.localId)

/--
Run isolated highlighted-code rendering and preserve both useful outcomes.

The compact template is what normal pages should use: hover references are kept
as local ids so repeated payloads can be registered once in the page hover
table. The same template also reconstructs self-contained snippets for isolated
previews, where there is no surrounding page table to consult. Keeping one template avoids
holding both full HTML forms for every external declaration while a large
blueprint page is generated.

We do not assign final Verso hover ids here because there is no final page
`Html.State` yet. Assigning stable ids would require a separate Blueprint hover
lookup scheme for every highlighted token payload, duplicating Verso's page
dedup table instead of using it.
-/
private def renderWithHoverPayloads
    (ctx : Verso.Code.HighlightHtmlM.Context Verso.Genre.Manual)
    (html : ExternalDeclHighlightRender ExternalDeclHtml) : ExternalDeclRenderedHtml :=
  let (html, hoverState) := (html.run ctx).run {}
  {
    html := (templateVersoHoverAttrs html hoverState.dedup).asString
    hoverPayloads := hoverPayloads hoverState.dedup
  }

private def highlightedToHtml (h : SubVerso.Highlighting.Highlighted) :
    ExternalDeclHighlightRender ExternalDeclHtml :=
  runHighlightedHtml (h.toHtml (g := Verso.Genre.Manual))

private def renderExternalDeclSignatureVariant
    (keywordText : String) (signature : SubVerso.Highlighting.Highlighted) :
    ExternalDeclHighlightRender ExternalDeclHtml :=
  open Verso.Output.Html in do
  let signatureHtml ← highlightedToHtml signature
  pure {{
    <pre class="bp_external_decl_signature signature hl lean block">
      <span class="keyword token">{{.text true keywordText}}</span> " " {{signatureHtml}}
    </pre>
  }}

private def signatureToHtml (keywordText : String) (sig : Verso.Genre.Manual.Signature) :
    ExternalDeclHighlightRender ExternalDeclHtml :=
  open Verso.Output.Html in do
  let wide ← renderExternalDeclSignatureVariant keywordText sig.wide
  let narrow ← renderExternalDeclSignatureVariant keywordText sig.narrow
  pure {{
    <div class="bp_external_decl_signature_wrap">
      <div class="wide-only">{{wide}}</div>
      <div class="narrow-only">{{narrow}}</div>
    </div>
  }}

/-- A citation of the bibliography entry `item` in a docstring, showing `text`: a link marked for
`rewriteDeclLinks`, which resolves `bib:KEY` to the entry's address on the page (class
`bp_bibcite`). -/
private def docstringCitationHtml (item : Informal.BibTeX.BibItem) (text : String) : ExternalDeclHtml :=
  open Verso.Output.Html in
  {{ {{.text false s!"{declMarkerOpenPrefix}{declMarkerEncode ("bib:" ++ item.key)}|-->"}}
     {{.text true text}}
     {{.text false declMarkerClose}} }}

/-- A docstring as HTML (`Informal.DocstringHtml.render?`), with its citations linked; as written,
in a `<pre>`, when it is not Markdown that renders. -/
private def plainDocstringHtml (env : Environment) (docs? : Option String) : ExternalDeclHtml :=
  open Verso.Output.Html in
  match docs? with
  | none => .empty
  | some docs =>
    match Informal.DocstringHtml.render? env docs docstringCitationHtml with
    | some html => {{<div class="docstring">{{html}}</div>}}
    | none => {{<pre class="docstring">{{.text true docs}}</pre>}}

private def docsHtml (env : Environment) (docs? : Option String) : ExternalDeclHtml :=
  open Verso.Output.Html in
  {{<div class="docs">{{plainDocstringHtml env docs?}}</div>}}

private def externalDeclSectionLabelId (decl : Name) (title : String) : String :=
  Informal.HtmlId.prefixed "bp-external-decl-section" s!"{decl.toString}:{title}"

private def renderTitledSection? (decl : Name) (title : String) (rows : Array ExternalDeclHtml) :
    Option ExternalDeclHtml :=
  open Verso.Output.Html in
  if rows.isEmpty then
    none
  else
    let labelId := externalDeclSectionLabelId decl title
    some {{
      <div class="bp_external_decl_section" role="group" aria-labelledby={{labelId}}>
        <p class="bp_external_decl_section_label" id={{labelId}}>{{.text true title}}</p>
        {{rows}}
      </div>
    }}

private def kindMarkerOfDeclType : Verso.Genre.Manual.Block.Docstring.DeclType → String
  | .theorem => "theorem"
  | .axiom _ => "axiom"
  | .opaque _ => "opaque"
  | .def _ => "def"
  | .structure true .. => "class"
  | .structure false .. => "structure"
  | .inductive .. => "inductive"
  | .ctor .. => "constructor"
  | .recursor _ => "recursor"
  | .quotPrim _ => "primitive"
  | .other => "def"

private structure ExternalDeclPresentation where
  kindClass : String
  kindMarker : String
  keywordText : String

structure ExternalDeclHeaderBadge where
  className : String
  text : String

structure ExternalDeclHeaderSource where
  text : String
  href? : Option String := none

private def countMeta? (singular plural : String) (count : Nat) : Option String :=
  if count == 0 then
    none
  else
    some s!"{count} {if count == 1 then singular else plural}"

private def keywordTextOfDefinitionSafety (safety : DefinitionSafety) (base : String) : String :=
  match safety with
  | .unsafe => s!"unsafe {base}"
  | .partial => s!"partial {base}"
  | .safe => base

private def externalDeclPresentation
    (declType : Verso.Genre.Manual.Block.Docstring.DeclType) (cinfo : ConstantInfo) :
    ExternalDeclPresentation :=
  let kindMarker := kindMarkerOfDeclType declType
  match cinfo with
  | .defnInfo defn =>
    if defn.hints.isAbbrev then
      {
        kindClass := s!"{kindMarker} abbrev"
        kindMarker := "abbrev"
        keywordText := keywordTextOfDefinitionSafety defn.safety "abbrev"
      }
    else
      {
        kindClass := kindMarker
        kindMarker
        keywordText := keywordTextOfDefinitionSafety defn.safety "def"
      }
  | _ =>
      {
        kindClass := kindMarker
        kindMarker
        keywordText := kindMarker
      }

private def renderExternalDeclWrapper
    (decl : Name) (kindClass : String) (kindMarker : String)
    (signature : ExternalDeclHtml) (body : ExternalDeclHtml)
    (headerBadge? : Option ExternalDeclHeaderBadge := none)
    (headerMeta : Array String := #[])
    (headerSource? : Option ExternalDeclHeaderSource := none) : ExternalDeclHtml :=
  open Verso.Output.Html in
  let headerMetaHtml : ExternalDeclHtml :=
    if headerMeta.isEmpty then
      .empty
    else
      {{<span class="bp_external_decl_header_meta">{{.text true s!"({String.intercalate ", " headerMeta.toList})"}}</span>}}
  let headerSourceHtml : ExternalDeclHtml :=
    match headerSource? with
    | none => .empty
    | some source =>
      let sourceNode : ExternalDeclHtml :=
        match source.href? with
        | some href =>
          {{<a class="bp_external_decl_source_path" href={{href}}>{{.text true source.text}}</a>}}
        | none =>
          {{<span class="bp_external_decl_source_path">{{.text true source.text}}</span>}}
      {{
        <span class="bp_external_decl_source">
          "defined in " {{sourceNode}}
        </span>
      }}
  {{
    <div class={{s!"declaration decl {kindClass}"}} data-decl={{decl.toString}} data-kind={{kindMarker}}>
      <div class="bp_external_decl_kicker">
        <div class="bp_external_decl_kicker_main">
          <span class="bp_external_decl_kind">{{.text true kindMarker}}</span>
          {{headerMetaHtml}}
          {{headerSourceHtml}}
        </div>
        <div class="bp_external_decl_kicker_status">
          {{if let some badge := headerBadge? then
            {{<span class={{s!"bp_external_status_badge bp_external_decl_header_status {badge.className}"}}>{{.text true badge.text}}</span>}}
          else .empty}}
        </div>
      </div>
      {{signature}}
      <div class="bp_external_decl_body">{{body}}</div>
    </div>
  }}

private def visibilityHtml (v : Verso.Genre.Manual.Block.Docstring.Visibility) : ExternalDeclHtml :=
  open Verso.Output.Html in
  match v with
  | .public => .empty
  | .private => {{<span class="keyword">"private"</span>" "}}
  | .protected => .empty

private def renderDocNameCtor (env : Environment)
    (docName : Verso.Genre.Manual.Block.Docstring.DocName) :
    ExternalDeclHighlightRender ExternalDeclHtml :=
  open Verso.Output.Html in do
  let signatureHtml ← highlightedToHtml docName.signature
  pure {{
    <div class="constructor">
      <pre class="name-and-type hl lean">{{signatureHtml}}</pre>
      {{docsHtml env docName.docstring?}}
    </div>
  }}

private def renderFieldSignature (env : Environment)
    (field : Verso.Genre.Manual.Block.Docstring.FieldInfo) :
    ExternalDeclHighlightRender ExternalDeclHtml :=
  open Verso.Output.Html in do
  let inheritedInfo : ExternalDeclHtml :=
    if field.fieldFrom.isEmpty then
      .empty
    else
      let inheritedRows : Array ExternalDeclHtml :=
        field.fieldFrom.toArray.map fun parent =>
          {{<li><code>{{.text true parent.name.toString}}</code></li>}}
      {{
        <div class="inheritance docs">
          "Inherited from "
          <ol>{{inheritedRows}}</ol>
        </div>
      }}
  let fieldNameHtml ← highlightedToHtml field.fieldName
  let fieldTypeHtml ← highlightedToHtml field.type
  pure {{
    <section class="subdocs">
      <pre class="name-and-type hl lean">
        {{visibilityHtml field.visibility}}{{fieldNameHtml}} " : " {{fieldTypeHtml}}
      </pre>
      {{inheritedInfo}}
      {{docsHtml env field.docString?}}
    </section>
  }}

private def renderParentsSection
    (decl : Name)
    (parents : Array Verso.Genre.Manual.Block.Docstring.ParentInfo) :
    ExternalDeclHighlightRender (Option ExternalDeclHtml) :=
  open Verso.Output.Html in do
  if parents.isEmpty then
    pure none
  else
    let rows ← parents.mapM fun parent => do
      let parentHtml ← highlightedToHtml parent.parent
      pure {{<li><code class="hl lean inline">{{parentHtml}}</code></li>}}
    let labelId := externalDeclSectionLabelId decl "Extends"
    pure <| some {{
      <div class="bp_external_decl_section" role="group" aria-labelledby={{labelId}}>
        <p class="bp_external_decl_section_label" id={{labelId}}>"Extends"</p>
        <ul class="extends">{{rows}}</ul>
      </div>
    }}

private def safetyHeaderMeta (cinfo : ConstantInfo) : Array String :=
  match cinfo with
  | .defnInfo defn =>
    match defn.safety with
    | .unsafe => #["unsafe"]
    | .partial => #["partial"]
    | .safe => #[]
  | _ => #[]

private def renderExternalDeclHeaderMeta
    (declType : Verso.Genre.Manual.Block.Docstring.DeclType) :
    Array String := Id.run do
  let mut items : Array String := #[]
  match declType with
  | .structure isClass _ _ fieldInfo _ parents =>
    if !parents.isEmpty then
      items := items.push s!"extends {parents.size}"
    let visibleFields := fieldInfo.filter (fun f => f.subobject?.isNone)
    if let some fieldCount := countMeta?
        (if isClass then "method" else "field")
        (if isClass then "methods" else "fields")
        visibleFields.size then
      items := items.push fieldCount
  | .inductive ctors numArgs propOnly =>
    if let some ctorCount := countMeta? "constructor" "constructors" ctors.size then
      items := items.push ctorCount
    if propOnly then
      items := items.push "Prop"
    if let some paramCount := countMeta? "parameter" "parameters" numArgs then
      items := items.push paramCount
  | _ => pure ()
  return items

/--
Highlighted code from a `Format` with position information, laid out at `width` columns: the
pipeline of `Verso.Genre.Manual.Signature.forName` (`tagCodeInfos`, SubVerso's `renderTagged`).
-/
private def highlightFormat (fwi : FormatWithInfos) (width : Nat) :
    MetaM SubVerso.Highlighting.Highlighted := do
  let ctx : Elab.ContextInfo := {
    env           := (← getEnv)
    mctx          := (← getMCtx)
    options       := (← getOptions)
    currNamespace := (← getCurrNamespace)
    openDecls     := (← getOpenDecls)
    fileMap       := default
    ngen          := (← getNGen)
  }
  let tagged ← Lean.Widget.tagCodeInfos ctx fwi.infos
    (Lean.Widget.TaggedText.prettyTagged (w := width) fwi.fmt)
  let hlCtx : SubVerso.Highlighting.Context := ⟨{}, false, false, [], false, (← IO.mkRef {})⟩
  (SubVerso.Highlighting.renderTagged none tagged :
    ReaderT SubVerso.Highlighting.Context MetaM _) hlCtx

/--
The body of a plain definition, pretty-printed under its binders as highlighted code at the given
width, laid out as the continuation ` :=\n  …` of the signature. `none` for everything that is not a
plain definition: theorems (proof terms), instances, structures, inductives, axioms and opaques.

The binders are opened with `lambdaTelescope`, so the body refers to the same names the signature
shows. Hovers are produced exactly as for the signature (`tagCodeInfos` followed by SubVerso's
`renderTagged`).
-/
private def definitionBodyHighlighted? (cinfo : ConstantInfo) (width : Nat) :
    MetaM (Option SubVerso.Highlighting.Highlighted) := do
  let .defnInfo defn := cinfo | return none
  if ← Meta.isInstance defn.name then return none
  lambdaTelescope defn.value fun _ body => do
    let (⟨fmt, infos⟩ : FormatWithInfos) ←
      withOptions (·.setBool `pp.tagAppFns true) <| PrettyPrinter.ppExprWithInfos body
    let fmt := Format.text " :=" ++ Format.nest 2 (Format.line ++ fmt)
    return some (← highlightFormat ⟨fmt, infos⟩ width)

private def stripInfoSyntax : Syntax → Syntax
  | .ident _ substr x pre => .ident .none substr x pre
  | .node _ kind args => .node .none kind (args.map stripInfoSyntax)
  | .atom _ x => .atom .none x
  | .missing => .missing

private def stripRootPrefixSyntax (stx : Syntax) : Syntax :=
  stx.rewriteBottomUp fun
    | .ident info substr x pre => .ident info substr (x.replacePrefix `_root_ .anonymous) pre
    | s => s

/--
The declaration header without its universe parameter list: Verso's `Signature.forName` prints
`Full.Name.{u_1, u_2} (binders) : type`; this is the same delaboration with `universes := false`,
the name written relative to the open namespaces (as the binders and body are), without its own
hover (no link from a declaration to itself), laid out at both widths.
-/
private def signatureWithoutUniverses (decl : Name) : MetaM Verso.Genre.Manual.Signature := do
  let cinfo ← getConstInfo decl
  let e := Expr.const decl (cinfo.levelParams.map mkLevelParam)
  let (stx, infos) ← withOptions (·.setBool `pp.tagAppFns true) <|
    PrettyPrinter.delabCore e
      (delab := PrettyPrinter.Delaborator.delabConstWithSignature (universes := false))
  let stx := stripRootPrefixSyntax stx.raw
  let opens : List Name := (← getOpenDecls).filterMap fun
    | .simple ns _ => some ns
    | .explicit .. => none
  let stx := stx.setArg 0 (mkIdent (shortenName opens decl))
  let fmt ← PrettyPrinter.ppTerm ⟨stx⟩
  let fwi : FormatWithInfos := ⟨fmt, infos⟩
  return { wide := ← highlightFormat fwi 72, narrow := ← highlightFormat fwi 42 }

/-- The signature of `decl` extended by the body of the definition, when there is one to show. -/
private def signatureWithBody (decl : Name) (cinfo : ConstantInfo) (showBody showUniverses : Bool) :
    MetaM Verso.Genre.Manual.Signature := do
  let signature ←
    if showUniverses then Verso.Genre.Manual.Signature.forName decl
    else signatureWithoutUniverses decl
  if !showBody then return signature
  match ← definitionBodyHighlighted? cinfo 72, ← definitionBodyHighlighted? cinfo 42 with
  | some bodyWide, some bodyNarrow =>
    return { wide := signature.wide ++ bodyWide, narrow := signature.narrow ++ bodyNarrow }
  | _, _ => return signature

private def renderDeclHtmlDocstringFromInfoE
    (decl : Name) (cinfo : ConstantInfo)
    (headerBadge? : Option ExternalDeclHeaderBadge := none)
    (headerSource? : Option ExternalDeclHeaderSource := none)
    (showBody : Bool := true) (showUniverses : Bool := false)
    (stripSourceRelation : Bool := false) : MetaM ExternalDeclRenderResult :=
  open Verso.Output.Html in do
  let env ← getEnv
  let declType ←
    withOptions (verso.docstring.allowMissing.set · true) <|
      Verso.Genre.Manual.Block.Docstring.DeclType.ofName decl (hideStructureConstructor := true)
  let signature ← signatureWithBody decl cinfo showBody showUniverses
  let docs? ← liftM <| findDocString? env decl
  -- The node shows the "Relation to the source." items as annotation boxes.
  let docs? :=
    if stripSourceRelation then docs?.map SourceRelation.stripSection else docs?
  let docsBaseUrl := verso.blueprint.externalCode.docsBaseUrl.get (← getOptions)

  let rendered := renderWithHoverPayloads (highlightedHtmlContext env docsBaseUrl) <| do
    let ctorSection? : Option ExternalDeclHtml ←
      match declType with
      | .structure isClass ctor? _ _ _ _ =>
        match ctor? with
        | some ctor =>
          let title := if isClass then "Instance Constructor" else "Constructor"
          let ctorHtml ← renderDocNameCtor env ctor
          pure <| renderTitledSection? decl title #[ctorHtml]
        | none => pure none
      | _ => pure none

    let methodsOrFieldsSection? : Option ExternalDeclHtml ←
      match declType with
      | .structure isClass _ _ fieldInfo _ _ =>
        let rows ← fieldInfo.filter (fun f => f.subobject?.isNone) |>.mapM (renderFieldSignature env)
        pure <| renderTitledSection? decl (if isClass then "Methods" else "Fields") rows
      | _ => pure none

    let parentsSection? : Option ExternalDeclHtml ←
      match declType with
      | .structure _ _ _ _ parents _ => renderParentsSection decl parents
      | _ => pure none

    let inductiveCtorsSection? : Option ExternalDeclHtml ←
      match declType with
      | .inductive ctors _ _ =>
        let rows ← ctors.mapM (renderDocNameCtor env)
        pure <| renderTitledSection? decl "Constructors" rows
      | _ => pure none

    let mut sections : Array ExternalDeclHtml := #[]
    if let some s := ctorSection? then
      sections := sections.push s
    if let some s := parentsSection? then
      sections := sections.push s
    if let some s := methodsOrFieldsSection? then
      sections := sections.push s
    if let some s := inductiveCtorsSection? then
      sections := sections.push s

    let presentation := externalDeclPresentation declType cinfo
    let signatureHtml ← signatureToHtml presentation.keywordText signature
    let headerMeta := safetyHeaderMeta cinfo ++ renderExternalDeclHeaderMeta declType

    let body : ExternalDeclHtml :=
      if sections.isEmpty then
        plainDocstringHtml env docs?
      else
        {{ {{plainDocstringHtml env docs?}} {{sections}} }}
    pure <| renderExternalDeclWrapper
      decl presentation.kindClass presentation.kindMarker signatureHtml body
      (headerBadge? := headerBadge?) (headerMeta := headerMeta) (headerSource? := headerSource?)
  pure <| .ok rendered

/--
Render one declaration directly from known declaration facts.
Errors represent rendering failures only; declaration lookup is handled by callers.
With `stripSourceRelation`, the docstring is shown without its "Relation to the source." section
(`SourceRelation.stripSection`), which the embedding node renders as annotation boxes.
-/
def renderDeclHtmlDirectFromInfoE
    (decl : Name) (cinfo : ConstantInfo)
    (headerBadge? : Option ExternalDeclHeaderBadge := none)
    (headerSource? : Option ExternalDeclHeaderSource := none)
    (showBody : Bool := true) (showUniverses : Bool := false)
    (stripSourceRelation : Bool := false) : MetaM ExternalDeclRenderResult := do
  try
    renderDeclHtmlDocstringFromInfoE decl cinfo
      (headerBadge? := headerBadge?) (headerSource? := headerSource?) (showBody := showBody)
      (showUniverses := showUniverses) (stripSourceRelation := stripSourceRelation)
  catch ex =>
    return .error (.exception decl (← ex.toMessageData.toString))

/-- Render one declaration directly from the in-memory `Environment` (no database, no source parsing). -/
def renderDeclHtmlNodeDirect? (decl : Name) : MetaM (Option ExternalDeclHtml) := do
  let decl := decl.eraseMacroScopes
  try
    let env ← getEnv
    let some cinfo := env.find? decl
      | return none
    let showBody := verso.blueprint.externalCode.definitionBodies.get (← getOptions)
    let showUniverses := verso.blueprint.externalCode.showUniverses.get (← getOptions)
    match ← renderDeclHtmlDirectFromInfoE decl cinfo (showBody := showBody)
        (showUniverses := showUniverses) with
    | .ok html => return some (.text false html.selfContained)
    | .error err =>
      logError m!"External declaration rendering failed for {decl}: {err.message}"
      return none
  catch ex =>
    logError m!"External declaration rendering failed for {decl}: {← ex.toMessageData.toString}"
    return none

end Informal

/- 
Copyright (c) 2026 Lean FRO LLC. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Author: Emilio J. Gallego Arias
-/

import Lean
import VersoManual
import VersoBlueprint.PreviewCache

/-!
Shared link-resolution policies for Blueprint renderers.

Most callers should not need to know which Verso traversal domain stores a
target. This module gives them small, named policies instead: resolve a plain
domain object, resolve an inline Lean declaration, or resolve the best link for
an informal block's Lean declaration.
-/

namespace Informal.Resolve

open Lean

def informalDomainName : Name := Name.mkSimple "Informal.Block.informal"
def informalCodeDomainName : Name := Name.mkSimple "Informal.Block.informalCode"
def informalRustCodeDomainName : Name := Name.mkSimple "Informal.Block.informalRustCode"
/-- Traversal domain for declared source documents. -/
def sourceDocumentDomainName : Name := Name.mkSimple "Informal.Source.document"
/--
Traversal domain for external-markup attachments.

This is a semantic domain, not a rendered-preview cache. `Block.externalMarkup`
stores one object per Blueprint label here so later `tex`/`md` witness blocks
can merge by label during traversal. Manifest construction reads this domain to
attach markup to preview-backed block entries, or to emit semantic-only
`externalMarkup` entries for witness-only labels.
-/
def externalMarkupDomainName : Name := Name.mkSimple "Informal.Block.externalMarkup"
def informalPreviewDomainName : Name := Name.mkSimple "Informal.Block.informalPreview"
def informalGroupDomainName : Name := Name.mkSimple "Informal.Block.group"
def graphDomainName : Name := Name.mkSimple "Informal.Block.graph"
/- 
Domain that stores anchors for rendered external declaration rows.

We intentionally keep this separate from `inlineLeanDeclDomainName`: inline Lean links are
declaration-anchor-centric (one destination per declaration), while rendered external rows are
occurrence-centric (one destination per visible code occurrence and canonical declaration).
A label-level fallback names the first visible code row when the selected statement
does not display code. This allows summary/graph UI to jump to a rendered instance, even when the same declaration
is referenced by many blueprint entries. Inline preview bodies themselves are keyed by the owning
source code-block identity.
-/
def externalRenderedDeclDomainName : Name := Name.mkSimple "Informal.Block.externalRenderedDecl"
/--
Domain that names, for each declaration presented at some node, the node whose rendering of it
declaration links go to (keyed by the declaration's full name; object data
`{"label", "definition"}`).
The canonical node is the first node in document order whose `(lean := ...)` list names the
declaration, except that a definition node takes precedence over a theorem-like node.
-/
def canonicalDeclDomainName : Name := Name.mkSimple "Informal.Block.canonicalDecl"
def bibliographyDomainName : Name := Name.mkSimple "Informal.Block.bpCitations"

/-- A bibliography label as a `Name`: `hover.cite` as the hierarchical name, a label that is not
one as a simple name. -/
def parseBibLabel (s : String) : Name :=
  let s := s.trimAscii.toString
  let n := s.toName
  if n.isAnonymous then Name.mkSimple s else n

/-- A bibliography label normalized through `parseBibLabel`. -/
def normalizeLabel (label : String) : String :=
  (parseBibLabel label).toString

/--
Stable slug used in bibliography fragment URLs and citation preview keys.

This intentionally keeps the historical lowercase, hyphen-separated bibliography
anchor form instead of `Informal.HtmlId.key`. Use the `HtmlId` encoder for
opaque generated element ids; citation anchors are user-visible URL fragments.
-/
def citationAnchorId (label : String) : String :=
  let base := normalizeLabel label
  base.foldl (init := "") fun acc c =>
    if c.isAlphanum then
      acc.push c.toLower
    else
      acc.push '-'
def citationPreviewDomainName : Name := Name.mkSimple "Informal.Inline.bpCite.previews"
def bibtexCitationPreviewDomainName : Name := Name.mkSimple "Informal.Inline.bibCite.previews"
def citationUsageDomainName : Name := Name.mkSimple "Informal.Inline.bpCite.usages"
/--
Domain that stores declaration anchors for inline Lean code.

Blueprint code blocks currently elaborate via `Verso.Genre.Manual.InlineLean.Block.lean`,
which registers defined declarations in the Manual `example` domain through
`Verso.Genre.Manual.saveExampleDefs`. We intentionally reuse that index here.
-/
def inlineLeanDeclDomainName : Name := ``Verso.Genre.Manual.example

/--
Key for one rendered external declaration target.

The `decl` input should be canonicalized by callers (for example using `ExternalRef.canonical`).
-/
def externalRenderedDeclTargetKey (occurrence : Verso.Multi.InternalId) (decl : Name) : String :=
  s!"{(toJson occurrence).compress}|{decl}"

/-- First visible code row, independent of the selected prose occurrence. -/
def externalRenderedDeclFallbackKey (label decl : Name) : String :=
  s!"label:{label}|{decl}"

def resolveDomainHref? (s : Verso.Genre.Manual.TraverseState) (domain : Name) (label : String) :
    Option String :=
  match s.resolveDomainObject domain label with
  | .ok dest => some dest.relativeLink
  | .error _ => none

def resolveDomainHrefs (s : Verso.Genre.Manual.TraverseState) (domain : Name) (label : String) :
    Array String :=
  match s.getDomainObject? domain label with
  | none => #[]
  | some obj =>
    let hrefs := obj.ids.toArray.filterMap fun id =>
      (s.externalTags[id]?).map (·.relativeLink)
    hrefs.qsort (fun a b => a < b)

def resolveInlineLeanDeclHref? (s : Verso.Genre.Manual.TraverseState) (decl : Name) : Option String :=
  match resolveDomainHref? s inlineLeanDeclDomainName decl.toString with
  | some href => some href
  | none =>
    match s.domains.get? inlineLeanDeclDomainName with
    | none => none
    | some dom =>
      let pref := decl.toString ++ " (in "
      let cands := dom.objects.foldl (init := #[]) fun acc key _obj =>
        if key == decl.toString || key.startsWith pref then
          acc.push key
        else
          acc
      if cands.size = 1 then
        resolveDomainHref? s inlineLeanDeclDomainName cands[0]!
      else
        none

def resolveRenderedExternalDeclHref? (s : Verso.Genre.Manual.TraverseState)
    (label decl : Name) : Option String :=
  (do
    let selected ← s.getDomainObject? informalPreviewDomainName (PreviewCache.key label .statement)
    let occurrence ← (selected.data.getObjValAs? (Option Verso.Multi.InternalId) "target").toOption.join
    resolveDomainHref? s externalRenderedDeclDomainName (externalRenderedDeclTargetKey occurrence decl)) <|>
  resolveDomainHref? s externalRenderedDeclDomainName (externalRenderedDeclFallbackKey label decl)

/-- The canonical node presenting the declaration named `decl` (`Name.toString`), and the
declaration's name. -/
def canonicalDecl? (s : Verso.Genre.Manual.TraverseState) (decl : String) : Option (Name × Name) := do
  let obj ← s.getDomainObject? canonicalDeclDomainName decl
  let label ← (obj.data.getObjValAs? Name "label").toOption
  let name ← (obj.data.getObjValAs? Name "decl").toOption
  return (label, name)

/--
The link to the canonical node's rendering of the declaration named `decl` (`Name.toString`),
when some node presents it.
-/
def resolveCanonicalDeclHref? (s : Verso.Genre.Manual.TraverseState) (decl : String) :
    Option String := do
  let (label, name) ← canonicalDecl? s decl
  resolveRenderedExternalDeclHref? s label name

/-- The full names of all declarations presented at some node. -/
def canonicalDeclNames (s : Verso.Genre.Manual.TraverseState) : Array String :=
  match s.domains.get? canonicalDeclDomainName with
  | none => #[]
  | some dom => dom.objects.foldl (init := #[]) fun acc key _ => acc.push key

/--
Resolve a Lean declaration link as seen from one informal block.

If the block rendered the declaration in its external-code panel, prefer that
row: it lands the reader on the concrete code that the block is discussing.
If no row was registered, fall back to the ordinary inline-Lean declaration
anchor shared by the rest of the document.
-/
def resolveInformalDeclHref? (s : Verso.Genre.Manual.TraverseState)
    (label decl : Name) : Option String :=
  match resolveRenderedExternalDeclHref? s label decl with
  | some href => some href
  | none => resolveInlineLeanDeclHref? s decl

end Informal.Resolve

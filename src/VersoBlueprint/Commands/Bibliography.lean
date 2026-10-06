/- 
Copyright (c) 2026 Lean FRO LLC. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Author: Emilio J. Gallego Arias
-/

import Lean
import Verso
import VersoManual
import VersoBlueprint.Cite
import VersoBlueprint.Commands.Common
import VersoBlueprint.Lib.ExtensionDecode
import VersoBlueprint.PreviewCache
import VersoBlueprint.Resolve
import VersoBlueprint.TeX
import VersoBlueprint.TraversalIndex

namespace Informal.Commands

open Lean Elab Command
open Verso.Genre.Manual.Bibliography

/-- The source of a bibliography entry: a `Citable` declaration registered with `[bib "label"]`, or
an entry of a BibTeX file registered with `blueprint_bibliography_file`. -/
inductive BibliographySource where
  | citable (citation : Citable)
  | bibtex (item : Informal.BibTeX.BibItem)
deriving FromJson, ToJson

structure BibliographyEntry where
  label : String
  source : BibliographySource
deriving FromJson, ToJson

/-- The key the entries are listed by: `Citable` entries by author and year, BibTeX entries in
the order BibtexQuery sorted them (by author, year and title), after the `Citable` ones. -/
def BibliographyEntry.sortKey (e : BibliographyEntry) : String :=
  match e.source with
  | .citable c => "0" ++ c.sortKey
  | .bibtex b => "1" ++ (String.ofList (List.replicate (8 - min 8 (toString b.order).length) '0')) ++ toString b.order

structure BibliographyData where
  entries : List BibliographyEntry := []
  /-- List only the entries the document cites (every `Citable` entry counts as cited; BibTeX
  entries are listed when some `{cite}` or docstring citation uses them). -/
  citedOnly : Bool := true
deriving FromJson, ToJson

/-- `s` with the characters TeX reads specially escaped. -/
def texEscape (s : String) : String :=
  s.foldl (init := "") fun acc c =>
    match c with
    | '\\' => acc ++ "\\textbackslash{}"
    | '{' => acc ++ "\\{"
    | '}' => acc ++ "\\}"
    | '&' => acc ++ "\\&"
    | '%' => acc ++ "\\%"
    | '#' => acc ++ "\\#"
    | '_' => acc ++ "\\_"
    | '$' => acc ++ "\\$"
    | '^' => acc ++ "\\textasciicircum{}"
    | '~' => acc ++ "\\textasciitilde{}"
    | c => acc.push c

def bibliographyCss := include_str "bibliography.css"

def bibliographyAssetBundle : BlueprintAssetBundle :=
  inlinePreviewAssetBundle (cssExtras := [bibliographyCss])

/-- The entries the bibliography lists, in order: all of `data.entries`, or, when `citedOnly`,
those with a recorded use (every `Citable` entry counts). -/
def listedEntries (st : Verso.Genre.Manual.TraverseState) (data : BibliographyData) :
    Array BibliographyEntry :=
  let entries := data.entries.toArray.qsort (fun a b => a.sortKey < b.sortKey)
  if data.citedOnly then
    entries.filter fun entry =>
      match entry.source with
      | .citable _ => true
      | .bibtex _ =>
        !(Informal.TraversalIndex.CitationUsages.hrefs st entry.label).isEmpty
          || ((Informal.TraversalIndex.CitationUsages.data? st entry.label).map (!·.uses.isEmpty)).getD false
  else
    entries

open Verso Doc Elab Genre Manual in
block_extension Block.bibliography (biblio : BibliographyData) where
  data := toJson biblio
  usePackages := Informal.TeX.standardMathUsePackages
  traverse id data _contents := do
    let some biblio ← Informal.ExtensionDecode.decode? (α := BibliographyData) data
        (fun _ => "Malformed data in Block.bibliography.traverse")
      | return none
    let path ← (·.path) <$> read
    let _ ← Verso.Genre.Manual.externalTag id path s!"--bp-bibliography"
    for entry in biblio.entries do
      modify fun st =>
        Informal.TraversalIndex.Bibliography.saveId st entry.label id
    return none
  toTeX :=
    open Verso.Output.TeX in
    some <| fun goI _goB _id data _blocks => do
      let .ok data := fromJson? (α := BibliographyData) data
        | Verso.reportError s!"Malformed data in Block.bibliography.toTeX: {data}"
          pure .empty
      let st ← Verso.Doc.TeX.state
      let entries := listedEntries st data
      let items ← entries.mapM fun entry => do
        match entry.source with
        | .citable c =>
          let rendered ← c.bibTeX goI
          pure \TeX{\item[\Lean{entry.label}] \Lean{rendered} s!"\n"}
        | .bibtex b =>
          pure \TeX{\item[\Lean{.raw s!"[{texEscape b.tag}]"}] \Lean{.raw (texEscape b.plaintext)} s!"\n"}
      pure \TeX{\begin{description}\Lean{items}\end{description}}
  toHtml :=
    open Verso.Doc.Html in
    open Verso.Output.Html in
    some <| fun goI _goB _id data _blocks => do
      let some data ← Informal.ExtensionDecode.decode? (α := BibliographyData) data
          (fun _ => "Malformed data in Block.bibliography.toHtml")
        | pure .empty
      let st ← HtmlT.state
      let entries := listedEntries st data
      let rows ← entries.mapM fun entry => do
        let rendered : Output.Html ← match entry.source with
          | .citable c => c.bibHtml goI
          | .bibtex b =>
            pure {{<span class="bp_bibliography_tag">{{s!"[{b.tag}]"}}</span> " " {{Output.Html.text false b.html}}}}
        let itemId := s!"bp-bib-{Informal.Cite.citationAnchorId entry.label}"
        let usageHrefs := Informal.TraversalIndex.CitationUsages.hrefs st entry.label
        let usageData : Informal.Cite.CitationUsageData :=
          (Informal.TraversalIndex.CitationUsages.data? st entry.label).getD {}
        let usageDetails := usageData.uses.toArray.qsort (fun a b => a.href < b.href)
        let usageRows : Array Output.Html :=
          if usageDetails.isEmpty then
            usageHrefs.foldl (init := #[]) fun out href =>
              out.push {{<li><a href={{href}}>s!"Citation use {out.size + 1}"</a></li>}}
          else
            usageDetails.map fun use =>
              let summaryText := use.summary.text st
              let inlineMeta : Output.Html :=
                let index? :=
                  match use.index.map (·.trimAscii.toString) with
                  | some i =>
                    if i.isEmpty then Option.none else some i
                  | Option.none => Option.none
                let detailText? : Option String :=
                  match use.kind, index? with
                  | some .page, some i => some s!"Cites page {i}"
                  | some k, some i => some s!"Cites {k.text} {i}"
                  | some .page, Option.none => some "Cites a page"
                  | some k, Option.none => some s!"Cites {k.text}"
                  | Option.none, some i => some s!"Cites reference {i}"
                  | Option.none, Option.none => use.locator.map (s!"Cites {·}")
                match detailText? with
                | some detail =>
                  {{<span class="bp_bibliography_use_inline_meta">
                    {{.text true s!" - {detail}"}}
                  </span>}}
                | Option.none => .empty
              let lineNode : Output.Html := {{
                <a href={{use.href}} class="bp_bibliography_use_line">
                  {{.text true summaryText}}
                  {{inlineMeta}}
                </a>}}
              let previewLine : Output.Html :=
                match use.summary.theoremCtx with
                | some theoremCtx =>
                  let previewKey :=
                    PreviewCache.key theoremCtx.label (if theoremCtx.isProof then .proof else .statement)
                  let previewId :=
                    s!"bp-bib-use-{Informal.HoverRender.previewKey use.href}"
                  let previewTarget := Informal.HoverRender.InlinePreviewTarget.withLookupKey
                    previewId summaryText previewKey
                  Informal.HoverRender.inlinePreviewTargetNode lineNode previewTarget
                | Option.none => lineNode
              {{<li class="bp_bibliography_use_item">
                {{previewLine}}
              </li>}}
        let usageCount := if usageDetails.isEmpty then usageHrefs.size else usageDetails.size
        pure {{
          <li id={{itemId}}>
            {{rendered}}
            <details class="bp_bibliography_uses">
              <summary>s!"Cited from ({usageCount})"</summary>
              <ul class="bp_bibliography_uses_list">
                {{if usageRows.isEmpty then {{<li class="bp_bibliography_empty">"No citation uses recorded."</li>}} else usageRows}}
              </ul>
            </details>
          </li>
        }}
      pure {{
        <div class="bp_bibliography">
          <details class="bp_bibliography_section" open>
            <summary>s!"Bibliography ({entries.size})"</summary>
            <ul class="bp_bibliography_list">
              {{if rows.isEmpty then {{<li class="bp_bibliography_empty">"No bibliography entries registered."</li>}} else rows}}
            </ul>
          </details>
        </div>
      }}
  extraCss := bibliographyAssetBundle.css
  extraJs := bibliographyAssetBundle.js

open Verso Doc Elab Syntax in
def mkBibliographyPart (stx : Syntax) (endPos : String.Pos.Raw) (citedOnly : Bool := true) :
    PartElabM FinishedPart := do
  let titlePreview := "Blueprint Bibliography"
  let titleInlines ← `(inline | "Blueprint Bibliography")
  let expandedTitle ← #[titleInlines].mapM (elabInline ·)
  let metadata : Option (TSyntax `term) := some (← `(term| { number := false }))
  let entries := Informal.Cite.allBibEntries (← getEnv)
  if verso.blueprint.debug.commands.get (← Lean.getOptions) then
    logInfo m!"Blueprint bibliography for {entries.length} entries"
  let refs : Array (TSyntax `term) ← entries.toArray.mapM fun (label, decl) =>
    `(BibliographyEntry.mk $(quote label) (BibliographySource.citable $(mkIdent decl)))
  let bibtexItems := Informal.BibTeX.allItems (← getEnv)
  let bibtexRefs : Array (TSyntax `term) ← bibtexItems.mapM fun item =>
    `(BibliographyEntry.mk $(quote item.key) (BibliographySource.bibtex $(quote item)))
  let refs := refs ++ bibtexRefs
  let block ← ``(Verso.Doc.Block.other
    (Informal.Commands.Block.bibliography
      (BibliographyData.mk (entries := ([$refs,*] : List BibliographyEntry))
        (citedOnly := $(quote citedOnly)))) #[])
  let subParts := #[]
  pure <| FinishedPart.mk stx stx expandedTitle titlePreview metadata #[block] subParts endPos

open Verso Doc Elab Syntax PartElabM in
/-- `{blueprint_bibliography}` adds the bibliography part: the `[bib]` entries and the BibTeX
entries the document cites. `{blueprint_bibliography_all}` lists every registered entry. -/
@[part_command Lean.Doc.Syntax.command]
public meta def blueprintBibliographyCmd : PartCommand
  | stx@`(block|command{blueprint_bibliography}) => do
    let endPos := stx.getTailPos?.get!
    closePartsUntil 1 endPos
    addPart (← mkBibliographyPart stx endPos)
  | stx@`(block|command{blueprint_bibliography_all}) => do
    let endPos := stx.getTailPos?.get!
    closePartsUntil 1 endPos
    addPart (← mkBibliographyPart stx endPos (citedOnly := false))
  | _ => (Lean.Elab.throwUnsupportedSyntax : PartElabM Unit)

end Informal.Commands

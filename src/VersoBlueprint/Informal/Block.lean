/-
Copyright (c) 2025 Lean FRO LLC. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Author: Emilio J. Gallego Arias, David Thrane Christiansen
-/

-- XXX VersoManual is not module yet
-- module

-- Blueprint library extending the Verso `Manual` genre.

import Lean.Elab.InfoTree.Types

import VersoManual

import VersoBlueprint.Commands.Common
import VersoBlueprint.Data
import VersoBlueprint.Environment
import VersoBlueprint.Editorial
import VersoBlueprint.Informal.Block.Assets
import VersoBlueprint.Informal.Block.Common
import VersoBlueprint.Informal.Block.Config
import VersoBlueprint.Informal.Block.RelatedPanel
import VersoBlueprint.Informal.Block.Render
import VersoBlueprint.Informal.Block.Store
import VersoBlueprint.Informal.Block.Traversal
import VersoBlueprint.Informal.CodeSummary
import VersoBlueprint.Informal.ExternalCode
import VersoBlueprint.Informal.ExternalMarkupRender
import VersoBlueprint.Lib.ExtensionDecode
import VersoBlueprint.Resolve
import VersoBlueprint.RenderingResolution
import VersoBlueprint.SourceAnnotations
import VersoBlueprint.Source.Metadata
import VersoBlueprint.TeX
import VersoBlueprint.TraversalIndex
import VersoBlueprint.Profiling

set_option doc.verso true

open Verso Doc Elab
open Verso.Genre Manual
open Verso.ArgParse
open Verso.Output.Html
open Lean.Doc.Syntax
open Lean Elab

namespace Informal
open CodeSummary

/- "Informal" Verso objects:

  - An informal verso object is identified by a label, and lives in the `informal` Verso domain.
  - For IO (Informal Object), we associate a `Data` entry, which mainly captures other objects the IO depends on
  - Objects are declared via directives / code blocks
  - Dependencies are declared via the {uses ...}`...` role, which _must_ be inside a directive.

Elaboration, traversal, and rendering are standard, using {ref VersoManual} helpers for custom blocks and inlines.

-/

open Verso.Doc.Html in
/-- Render this occurrence with relation previews restricted to the resources
prepared for its output. Semantic resolution and numbering remain occurrence-owned. -/
private def informalBlockToHtml (renderPreview : PreviewResources.Render := PreviewResources.immediate) :
    BlockToHtml Manual (ReaderT Multi.AllRemotes (ReaderT ExtensionImpls (BuildLogT IO))) :=
    fun _goI goB id data blocks => do
      match ← ExtensionDecode.decode? (α := BlockOccurrence) data
          (fun err => s!"Malformed data ({err}): {data}") with
      | none =>
        pure .empty
      | some occurrence =>
        let s ← HtmlT.state
        let ctxt ← HtmlT.context
        let some data ← ExtensionDecode.report? (RenderingResolution.occurrence s occurrence (some ctxt))
          | pure .empty
        let data := { data with
          hasFormalizationTodo := data.hasFormalizationTodo || blocks.any Editorial.hasFormalizationTodo ||
            (Informal.TraversalIndex.Nodes.occurrence? s data.label).any
              (fun (stored : BlockOccurrence) => stored.hasFormalizationTodo) }
        let data : BlockData := if data.legendInKicker then
            { data with codeData := data.codeData.map fun (code : BlockCodeData) => { code with
                externalDecls := code.externalDecls.map fun (ref : Data.ExternalRef) =>
                  { ref with legendInKicker := true } } }
          else data
        let markup :=
          (Informal.TraversalIndex.ExternalMarkup.data? s data.label).map (·.markup.toArray) |>.getD #[]
        -- The boxes taken from docstrings do not count as a body of the node: a node whose only
        -- blocks are those boxes still shows its external markup, followed by the boxes.
        let sourceItemBlocks := blocks.filter Editorial.isSourceItemBlock
        let selectedMarkupAndContent? :=
          match data.isProof with
          | false =>
              if blocks.all Editorial.isSourceItemBlock then
                Informal.ExternalMarkupRender.selectedContent? {} markup
              else
                none
          | true => none
        let sourceBackedAttrs :=
          match selectedMarkupAndContent? with
          | some (selectedMarkup, _) => Informal.ExternalMarkupRender.sourceBackedAttrs selectedMarkup
          | none => #[]
        let attrs := s.htmlId id ++ sourceBackedAttrs
        let codeHint? :=
          match data.isProof with
          | true => none
          | false => data.codeData
        let externalDecls := codeHint?.map (·.externalDecls) |>.getD #[]
        let getDeclHref (decl : Name) : Option String :=
          Resolve.resolveInformalDeclHref? s data.label decl
        let getDeclAnchorAttrs (decl : Data.ExternalRef) : Array (String × String) :=
          Informal.TraversalIndex.ExternalDeclAnchors.htmlIdAttrs s id decl.canonical
        let headingParts? : Option CodeSummary.RenderParts :=
          match data.isProof with
          | false => some <| CodeSummary.renderParts data {
              codeHref := Informal.TraversalIndex.InlineCode.firstHref? s data.label
              source := codeHint?
              inlineBlocks := Informal.TraversalIndex.InlineCode.blocks s data.label
            } getDeclHref
          | true => none
        let externalPanel : Output.Html ←
          match data.isProof with
          | false =>
            if externalDecls.isEmpty then
              pure .empty
            else
              let externalCdata : CodeSummary.ComputedData := {
                source := some { externalDecls := externalDecls }
              }
              let externalSummary := CodeSummary.renderPanelIndicator data.label externalCdata getDeclHref
              let panelHeader := codePanelHeader (data.display s)
              ExternalCode.renderPanelWithPageHovers
                panelHeader
                externalSummary.summaryTitle
                externalSummary.indicator
                externalDecls
                getDeclHref
                getDeclAnchorAttrs
                (folded := data.foldCodeBlock)
                (declHref := TraversalIndex.resolveExternalDeclLinkHref? s)
          | true => pure .empty
        let content ←
          match selectedMarkupAndContent? with
          | some (_, selectedContent) => pure (selectedContent ++ (← sourceItemBlocks.mapM goB))
          | none => blocks.mapM goB
        let codeEntry := (headingParts?.map (·.codeEntry)).getD .empty
        let usesEntry := RelatedPanel.renderUsesExtra s data renderPreview
        let headerExtras := HeaderExtras.forFacet data.isProof (HeaderExtra.uses usesEntry) fun _ => {
          group? := (RelatedPanel.renderGroupExtra s data renderPreview).map HeaderExtra.group
          usedBy? := some (HeaderExtra.usedBy (RelatedPanel.renderUsedByExtra s data renderPreview))
          markup? := renderExternalMarkupHeaderExtra? markup
          code? := some (HeaderExtra.code codeEntry)
        }
        -- Verso's <base> handles site-relative source paths; reader enrichment
        -- may supply an explicit published source base instead.
        let headerExtras := { headerExtras with
          source? := renderSourceHeaderExtra? data.sourceRef.toArray
            (sourceLinkBase data.readerContext ctxt.path.size) }
        return renderInformalBlockModel {
          data
          context := InformalBlockRenderContext.forBlock data
            ((data.display s).number?.getD data.label.toString)
            (proofCaption? := some (data.displayTitle s))
            (attrs := attrs)
            (headerExtras := headerExtras)
            (folded := data.foldInformalShell && !blocks.any Editorial.hasFormalizationTodo)
          content
          companionPanels := #[externalPanel]
        }

/- Informal custom blocks -/
block_extension Block.informal (data : BlockOccurrence) where
  -- for TOC
  -- localContentItem _ _ _ := none
  data := toJson data
  usePackages := Informal.TeX.standardMathUsePackages
  traverse id data _contents := do
    -- XXX: (maybe) lift the Except into the main monad error thread
    match ← ExtensionDecode.decode? (α := BlockOccurrence) data
        (fun err => s!"Malformed data ({err}): {data}") with
    | none =>
      pure none
    | some occurrence =>
      let occurrence := { occurrence with
        hasFormalizationTodo := _contents.any Editorial.hasFormalizationTodo }
      registerTraversedBlock id occurrence _contents
      return none
  toTeX := some <| fun _goI goB _id data blocks => do
      let .ok occurrence := fromJson? (α := BlockOccurrence) data
        | Verso.reportError s!"Malformed data in Block.informal.toTeX: {data}"
          pure .empty
      let st ← Verso.Doc.TeX.state
      let some data ← ExtensionDecode.report? (RenderingResolution.occurrence st occurrence)
        | pure .empty
      let title := data.displayTitle st
      let body ← blocks.mapM goB
      pure <| Informal.TeX.quotedBlock title body
  extraCss := Reader.css :: Informal.Block.Assets.blockCssAssets
  extraJs := Informal.Block.Assets.blockJsAssets
  toHtml := some (informalBlockToHtml PreviewResources.immediate)

/-- Bind the standard block HTML renderer's relation presentation hook.
Traversal, TeX, and other supplied extension hooks are retained. -/
def Block.withPreviewRendering (impls : ExtensionImpls)
    (renderPreview : PreviewResources.Render) : ExtensionImpls :=
  match impls.getBlock? ``Block.informal with
  | none => impls
  | some descriptor =>
    impls.insertBlock ``Block.informal
      { descriptor with toHtml := some (informalBlockToHtml renderPreview) }

/-- Resolve page relation previews immediately against prepared resources. -/
def Block.withPreviewAvailability (impls : ExtensionImpls)
    (available : PreviewKey → Bool) : ExtensionImpls :=
  Block.withPreviewRendering impls (PreviewResources.immediate available)

private structure ParsedDirectiveContents where
  sourceRef? : Option Source.Ref := none
  paperIdentity : Option Reader.PaperIdentity := none
  body : Array (TSyntax `block) := #[]

private def parseDirectiveSourceMetadata
    (cfg : Config) (contents : Array (TSyntax `block)) : DocElabM ParsedDirectiveContents := do
  let leading ← Source.Metadata.splitLeadingMetadata contents
  let mut paperIdentity := none
  let sourceRef? ←
    match leading.term? with
    | some term =>
        let metadata ← Source.Metadata.evalNodeMetadataInput term
        if let some identity := metadata.paperIdentity then
          if identity.isValid then
            paperIdentity := some identity
          else
            logErrorAt term m!"Label {cfg.label} has invalid paperIdentity metadata: a nonempty label and safe source URLs are required"
        if let some sourceRef := metadata.source? then
          let validationErrors := Source.Ref.validationErrors sourceRef
          for error in validationErrors do
            logErrorAt term m!"Label {cfg.label} has invalid source metadata: {toString error}"
          pure (some sourceRef)
        else
          pure none
    | none =>
        pure none
  let body ← Source.Metadata.visibleBlocksWithoutMetadata leading.body fun block =>
    logErrorAt block m!"Label {cfg.label} has a metadata block after visible content; Blueprint source metadata must be the first block inside the directive"
  pure { sourceRef?, paperIdentity, body }

private unsafe def retainElaboratedBlocksUnsafe (stxs : Array (TSyntax `term)) :
    TermElabM (Array (Doc.Block Genre.Manual) × TSyntax `term) := do
  if stxs.isEmpty then
    pure (#[], ← `(#[]))
  else
    let blockType ← Term.elabType (← `(Doc.Block Genre.Manual))
    let arrayType := mkApp (.const ``Array [0]) blockType
    let arraySyntax ← `(#[$stxs,*])
    let arrayExpr ← Term.elabTermAndSynthesize arraySyntax (some arrayType)
    let arrayExpr ← instantiateMVars arrayExpr
    let name ← mkFreshUserName `blueprintDirectiveBodyBlocks
    let decl := Declaration.defnDecl {
      name
      levelParams := []
      type := arrayType
      value := arrayExpr
      hints := .abbrev
      safety := .safe
    }
    Term.ensureNoUnassignedMVars decl
    -- This dynamically compiled declaration must remain a single reusable
    -- environment constant for preview evaluation and final reconstruction.
    withOptions (·.setBool `compiler.extract_closed false) <|
      addAndCompile decl
    let blocks ← Meta.evalExpr
      (Array (Doc.Block Genre.Manual)) arrayType (.const name [])
    let reference ← ``($(mkIdent name))
    pure (blocks, reference)

@[implemented_by retainElaboratedBlocksUnsafe]
private opaque retainElaboratedBlocks
    (stxs : Array (TSyntax `term)) :
    TermElabM (Array (Doc.Block Genre.Manual) × TSyntax `term)

private def expanderImpl (kind : Data.NodeKind) (isProof : Bool := false) : DirectiveExpanderOf Config
  | cfg, contents => do
    let blockRef ← getRef
    let label := cfg.label
    let prepare := do
      let resolved ← cfg.resolveForDirective kind isProof
      pure ({
        label, kind := resolved.envKind, codeHint := resolved.codeHint
        parent := resolved.parent, priority := resolved.priority, owner := resolved.owner
        tags := resolved.tags, effort := resolved.effort, prUrl := resolved.prUrl
        issueUrl := resolved.issueUrl
        deps := resolved.statementUses, proofUses := resolved.proofUses } : Environment.InProgress)
    let some ((retainedContents, sourceRef, paperIdentity), count) ← Environment.withDirective prepare blockRef do
        let parsedContents ← parseDirectiveSourceMetadata cfg contents
        -- Retained bodies are compiled now, before the enclosing document binds its
        -- reconstruction placeholder. Native Lean roles must serialize their hover
        -- data directly so these independently evaluated blocks remain closed.
        let contents ← (show DocElabM _ from fun ctx =>
          (parsedContents.body.mapM elabBlock) { ctx with docReconstructionPlaceholder := none })
        -- The "Relation to the source." items of the embedded declarations' docstrings, as
        -- annotation boxes under the statement.
        let contents ←
          match (Environment.informalExt.getState (← getEnv)).activeDirective.bind (·.codeHint) with
          | some (.external refs) =>
            pure (contents ++ (← SourceAnnotations.termsForRefs cfg.labelSyntax refs))
          | _ => pure contents
        let (previewBlocks, retainedContents) ← liftM <| retainElaboratedBlocks contents
        pure ((retainedContents, parsedContents.sourceRef?, parsedContents.paperIdentity), previewBlocks)
      | return ← ``(Block.concat #[])
    let opts ← getOptions
    let sourceLocation :=
      match ← Data.SourceLocation.ofSyntax? cfg.labelSyntax with
      | some location => Data.SourceLocationResult.found location
      | none =>
        Data.SourceLocationResult.unavailable s!"label source location unavailable for {label}"
    let data : BlockOccurrence := {
      isProof
      sourceRef
      paperIdentity
      label
      sourceLocation
      foldProofBlock := verso.blueprint.foldProofBlocks.get opts
      foldCodeBlock := verso.blueprint.foldCodeBlocks.get opts
      count
      numberingMode := numberingMode opts
      subNumberingPrefix := subNumberingPrefix opts
      subNumberingCounter := subNumberingCounter opts
    }
    ``(Block.other (Block.informal $(quote data)) $retainedContents)

private def directiveName (kind : Data.NodeKind) (isProof : Bool): String :=
  if isProof then "proof" else (toString kind).toLower

private def expander (kind : Data.NodeKind) (isProof : Bool := false) : DirectiveExpanderOf Config
  | cfg, contents => do
    let label := (directiveName kind isProof)
    Profile.withDocElab "directive" label <|
      (expanderImpl kind isProof) cfg contents

@[directive] def «definition» := expander .definition
@[directive] def «proposition» := expander .proposition
@[directive] def «lemma_» := expander .lemma
@[directive] def «theorem» := expander .theorem
@[directive] def «corollary» := expander .corollary
@[directive] def «proof» := expander .lemma (isProof := true)

end Informal

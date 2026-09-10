import VersoManual
import VersoBlueprint.TeX

open Verso Doc Elab Genre Manual Lean

namespace Informal.Editorial

/-- Editorial categories do not constitute mathematical evidence or proof status. -/
inductive Kind where
  | translation
  | «meta»
  | formalizationTodo
  | clarification
  | correction
  | outOfScope
deriving BEq, FromJson, ToJson, Quote

def Kind.key : Kind → String
  | .translation => "translation"
  | .meta => "meta"
  | .formalizationTodo => "formalizationTodo"
  | .clarification => "clarification"
  | .correction => "correction"
  | .outOfScope => "outOfScope"

def Kind.title : Kind → String
  | .translation => "Notation in Lean"
  | .meta => "Formalisation note"
  | .formalizationTodo => "Formalisation TODO"
  | .clarification => "Clarification"
  | .correction => "Correction"
  | .outOfScope => "Out of scope"

def correspondenceWarning : Output.Html :=
  .tag "span" #[("class", "bp-correspondence-warning")]
    (.text true "Formalisation TODO")

def css : String := r##"
.bp-editorial { margin:1rem 0; padding:.7rem 1rem; border-left:3px solid var(--bp-color-border-soft,#cbd5e1); background:var(--bp-color-bg-subtle,#f8fafc); font-style:normal; }
.bp-editorial-title { font-weight:650; font-size:.9rem; margin-bottom:.4rem; }
.bp-editorial-content > :first-child { margin-top:0; }
.bp-editorial-content > :last-child { margin-bottom:0; }
.bp-editorial[data-kind=formalizationTodo] { border-left:4px solid #b45309; background:light-dark(#fff7ed,#302015); }
.bp-editorial[data-kind=formalizationTodo] > .bp-editorial-title { color:light-dark(#9a3412,#fdba74); }
.bp-editorial[data-kind=clarification] { border-left-color:light-dark(#0369a1,#7dd3fc); }
.bp-editorial[data-kind=correction] { border-left-color:light-dark(#7e22ce,#d8b4fe); }
.bp-correspondence-warning { font-size:.8rem; font-weight:600; color:light-dark(#9a3412,#fdba74); }
"##

def render (kind : Kind) (contents : Array Output.Html) : Output.Html :=
  open Output.Html in
  {{<aside class="bp-editorial" data-kind={{kind.key}} aria-label={{kind.title}}>
    <div class="bp-editorial-title">{{.text true kind.title}}</div>
    <div class="bp-editorial-content">{{.seq contents}}</div>
  </aside>}}

block_extension Block.editorial (kind : Kind) where
  data := toJson kind
  extraCss := [css]
  traverse _ _ _ := pure none
  toHtml := some fun _ goB _ raw blocks => do
    let .ok kind := fromJson? (α := Kind) raw
      | Verso.reportError "Malformed editorial annotation"
        return .empty
    return render kind (← blocks.mapM goB)
  toTeX := some fun _ goB _ raw blocks => do
    let .ok kind := fromJson? (α := Kind) raw
      | Verso.reportError "Malformed editorial annotation"
        return .empty
    let body ← blocks.mapM goB
    return Informal.TeX.quotedBlock kind.title body

/-- Inspect the document tree, not rendered HTML or author-supplied approval flags. -/
partial def hasFormalizationTodo : Doc.Block Manual → Bool
  | .other ext children =>
    (ext.name == ``Block.editorial &&
      (fromJson? (α := Kind) ext.data).toOption == some .formalizationTodo) ||
      children.any hasFormalizationTodo
  | .concat bs | .blockquote bs => bs.any hasFormalizationTodo
  | .ul items | .ol _ items => items.any fun item => item.contents.any hasFormalizationTodo
  | .dl items => items.any fun item => item.desc.any hasFormalizationTodo
  | _ => false

private def expand (kind : Kind) : DirectiveExpanderOf Unit
  | _, contents => do
    let contents ← contents.mapM elabBlock
    ``(Verso.Doc.Block.other (Block.editorial $(quote kind)) #[$contents,*])

end Informal.Editorial

namespace Informal

/-- Harmless correspondence of notation only; never altered assumptions or conclusions. -/
@[directive] def translation : DirectiveExpanderOf Unit := Editorial.expand .translation

/-- Implementation and editorial commentary without mathematical authority. -/
@[directive] def «meta» : DirectiveExpanderOf Unit := Editorial.expand .meta

/-- Neutral account of missing statements or unsettled correspondence and possible resolutions.
Missing proofs alone use the existing proof status, not this directive. -/
@[directive] def formalizationTodo : DirectiveExpanderOf Unit := Editorial.expand .formalizationTodo

/-- A settled explicit convention where the paper is underspecified, not an unproved replacement. -/
@[directive] def clarification : DirectiveExpanderOf Unit := Editorial.expand .clarification

/-- A correction explained by linked mathematical evidence, never an editorial approval flag. -/
@[directive] def correction : DirectiveExpanderOf Unit := Editorial.expand .correction

/-- Deliberately omitted material not needed by the claims retained in scope.
Explain what is excluded and why; this does not discharge any mathematical obligation. -/
@[directive] def outOfScope : DirectiveExpanderOf Unit := Editorial.expand .outOfScope

end Informal

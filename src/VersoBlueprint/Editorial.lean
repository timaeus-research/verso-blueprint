import VersoManual
import VersoBlueprint.TeX

open Verso Doc Elab Genre Manual Lean

namespace Informal.Editorial

/-- Editorial categories do not constitute mathematical evidence or proof status. -/
inductive Kind where
  | translation
  | «meta»
  | discrepancy
deriving BEq, FromJson, ToJson, Quote

def Kind.key : Kind → String
  | .translation => "translation"
  | .meta => "meta"
  | .discrepancy => "discrepancy"

def Kind.title : Kind → String
  | .translation => "Notation in Lean"
  | .meta => "Formalization note"
  | .discrepancy => "Unresolved statement discrepancy"

def discrepancyCaveat : String :=
  "A proof-status badge concerns the Lean declaration, not its correspondence with the paper. This obligation remains open."

def correspondenceWarning : Output.Html :=
  .tag "span" #[("class", "bp-correspondence-warning")]
    (.text true "Statement correspondence unresolved")

def css : String := r##"
.bp-editorial { margin:1rem 0; padding:.7rem 1rem; border-left:3px solid var(--bp-color-border-soft,#cbd5e1); background:var(--bp-color-bg-subtle,#f8fafc); font-style:normal; }
.bp-editorial-title { font-weight:650; font-size:.9rem; margin-bottom:.4rem; }
.bp-editorial-content > :first-child { margin-top:0; }
.bp-editorial-content > :last-child { margin-bottom:0; }
.bp-editorial[data-kind=discrepancy] { border-left:4px solid #b45309; background:light-dark(#fff7ed,#302015); }
.bp-editorial[data-kind=discrepancy] > .bp-editorial-title { color:light-dark(#9a3412,#fdba74); }
.bp-editorial-caveat { margin:.6rem 0 0; font-size:.85rem; }
.bp-correspondence-warning { font-size:.8rem; font-weight:600; color:light-dark(#9a3412,#fdba74); }
"##

def render (kind : Kind) (contents : Array Output.Html) : Output.Html :=
  open Output.Html in
  {{<aside class="bp-editorial" data-kind={{kind.key}} aria-label={{kind.title}}>
    <div class="bp-editorial-title">{{.text true kind.title}}</div>
    <div class="bp-editorial-content">{{.seq contents}}</div>
    {{if kind == .discrepancy then
      {{<p class="bp-editorial-caveat">{{.text true discrepancyCaveat}}</p>}}
      else .empty}}
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
    let body := if kind == .discrepancy then body.push (.text discrepancyCaveat) else body
    return Informal.TeX.quotedBlock kind.title body

/-- Inspect the document tree, not rendered HTML or author-supplied approval flags. -/
partial def hasDiscrepancy : Doc.Block Manual → Bool
  | .other ext children =>
    (ext.name == ``Block.editorial &&
      (fromJson? (α := Kind) ext.data).toOption == some .discrepancy) ||
      children.any hasDiscrepancy
  | .concat bs | .blockquote bs => bs.any hasDiscrepancy
  | .ul items | .ol _ items => items.any fun item => item.contents.any hasDiscrepancy
  | .dl items => items.any fun item => item.desc.any hasDiscrepancy
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

/-- An outstanding statement-correspondence obligation, never an accepted difference. -/
@[directive] def discrepancy : DirectiveExpanderOf Unit := Editorial.expand .discrepancy

end Informal

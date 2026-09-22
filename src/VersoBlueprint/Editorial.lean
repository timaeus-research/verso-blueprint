import VersoManual
import VersoBlueprint.TeX

open Verso Doc Elab Genre Manual Lean
open Verso.ArgParse

namespace Informal.Editorial

/-- Editorial categories do not constitute mathematical evidence or proof status.

An annotation compares one item of the paper with the formalisation. Three questions decide its
kind, in order. Does the item have a formalised counterpart? If none: `unformalised` (with
`missing := statement | proof`) or `outOfScope` (none and none owed, by decision). For an item
with a counterpart of record, is the paper's claim true as printed? `correction` (false, an
unprinted hypothesis it needs included; the corrected version is stated) or `interpretation`
(underspecified; one reading is fixed). For a true claim, how do the statements compare? `restatement` (a logically equivalent
form of the whole statement, used sparingly), `strengthening` (the formal statement implies the
paper's, converse not claimed) or `gap` (weaker or incomparable). `translation` is the dictionary
(this Lean expression is the paper's such-and-such), orthogonal to the comparison. `meta` and
`formalizationTodo` are the framework's older kinds and remain available. -/
inductive Kind where
  | «meta»
  | formalizationTodo
  | unformalised
  | outOfScope
  | correction
  | interpretation
  | translation
  | restatement
  | strengthening
  | gap
deriving BEq, FromJson, ToJson, Quote, Repr

def Kind.key : Kind → String
  | .meta => "meta"
  | .formalizationTodo => "formalizationTodo"
  | .unformalised => "unformalised"
  | .outOfScope => "outOfScope"
  | .correction => "correction"
  | .interpretation => "interpretation"
  | .translation => "translation"
  | .restatement => "restatement"
  | .strengthening => "strengthening"
  | .gap => "gap"

def Kind.ofKey? : String → Option Kind
  | "meta" => some .meta
  | "formalizationTodo" => some .formalizationTodo
  | "unformalised" => some .unformalised
  | "outOfScope" => some .outOfScope
  | "correction" => some .correction
  | "interpretation" => some .interpretation
  | "translation" => some .translation
  | "restatement" => some .restatement
  | "strengthening" => some .strengthening
  | "gap" => some .gap
  | _ => none

def Kind.title : Kind → String
  | .meta => "Formalisation note"
  | .formalizationTodo => "Formalisation TODO"
  | .unformalised => "Unformalised"
  | .outOfScope => "Out of scope"
  | .correction => "Correction"
  | .interpretation => "Interpretation"
  | .translation => "Translation"
  | .restatement => "Restatement"
  | .strengthening => "Strengthening"
  | .gap => "Gap"

/-- The kinds that owe formalisation work; each marks the enclosing node's header. -/
def Kind.owesWork : Kind → Bool
  | .formalizationTodo | .unformalised | .gap => true
  | _ => false

/-- What an `unformalised` item lacks: a Lean statement, or only its proof. -/
inductive Missing where
  | statement
  | proof
deriving BEq, FromJson, ToJson, Repr

def Missing.key : Missing → String
  | .statement => "statement"
  | .proof => "proof"

def Missing.parse? : String → Option Missing
  | "statement" => some .statement
  | "proof" => some .proof
  | _ => none

/-- Whether a human has checked the annotation: an agent's assessment until then. -/
inductive Review where
  | unreviewed
  | reviewed (initials date : String)
deriving BEq, FromJson, ToJson, Repr

def Review.label : Review → String
  | .unreviewed => "unreviewed"
  | .reviewed initials date => s!"reviewed {initials} {date}"

def Review.state : Review → String
  | .unreviewed => "unreviewed"
  | .reviewed .. => "reviewed"

/-- `unreviewed`, or `reviewed <initials> <date>`. -/
def Review.parse? (s : String) : Option Review :=
  match (s.splitOn " ").filter (fun w => !w.isEmpty) with
  | ["unreviewed"] => some .unreviewed
  | ["reviewed", initials, date] => some (.reviewed initials date)
  | _ => none

/-- One annotation: its kind and its badges. -/
structure Annotation where
  kind : Kind
  review : Review := .unreviewed
  missing : Option Missing := none
deriving BEq, FromJson, ToJson, Repr

/-- Rebuild an annotation from the validated strings the block extension carries. -/
def Annotation.ofStrings (kindKey review missing : String) : Annotation :=
  { kind := (Kind.ofKey? kindKey).getD .meta
    review := (Review.parse? review).getD .unreviewed
    missing := Missing.parse? missing }

def correspondenceWarning : Output.Html :=
  .tag "span" #[("class", "bp-correspondence-warning")]
    (.text true "Formalisation TODO")

def css : String := r##"
.bp-editorial { margin:1rem 0; padding:.7rem 1rem; border-left:3px solid var(--bp-color-border-soft,#cbd5e1); background:var(--bp-color-bg-subtle,#f8fafc); font-style:normal; }
.bp-editorial-title { font-weight:650; font-size:.9rem; margin-bottom:.4rem; display:flex; flex-wrap:wrap; align-items:center; gap:.4rem; }
.bp-editorial-content > :first-child { margin-top:0; }
.bp-editorial-content > :last-child { margin-bottom:0; }
.bp-badge { display:inline-block; font-size:.7rem; font-weight:600; line-height:1.3; padding:.05rem .45rem; border-radius:.7rem; border:1px solid transparent; letter-spacing:.01em; }
.bp-badge-review[data-review=unreviewed] { color:light-dark(#475569,#cbd5e1); background:light-dark(#e2e8f0,#334155); }
.bp-badge-review[data-review=reviewed] { color:light-dark(#166534,#bbf7d0); background:light-dark(#dcfce7,#14532d); }
.bp-badge-missing { color:light-dark(#991b1b,#fecaca); background:light-dark(#fee2e2,#450a0a); }
.bp-editorial[data-kind=formalizationTodo], .bp-editorial[data-kind=gap] { border-left:4px solid #b45309; background:light-dark(#fff7ed,#302015); }
.bp-editorial[data-kind=formalizationTodo] > .bp-editorial-title, .bp-editorial[data-kind=gap] > .bp-editorial-title { color:light-dark(#9a3412,#fdba74); }
.bp-editorial[data-kind=unformalised] { border-left:4px solid #b91c1c; background:light-dark(#fef2f2,#2a1414); }
.bp-editorial[data-kind=unformalised] > .bp-editorial-title { color:light-dark(#991b1b,#fca5a5); }
.bp-editorial[data-kind=correction] { border-left-color:light-dark(#7e22ce,#d8b4fe); }
.bp-editorial[data-kind=correction] > .bp-editorial-title { color:light-dark(#6b21a8,#e9d5ff); }
.bp-editorial[data-kind=interpretation] { border-left-color:light-dark(#0369a1,#7dd3fc); }
.bp-editorial[data-kind=interpretation] > .bp-editorial-title { color:light-dark(#075985,#bae6fd); }
.bp-editorial[data-kind=translation] { margin:.5rem 0; padding:.35rem .8rem; border-left-color:light-dark(#64748b,#94a3b8); background:transparent; border-top:1px dotted light-dark(#cbd5e1,#475569); border-bottom:1px dotted light-dark(#cbd5e1,#475569); }
.bp-editorial[data-kind=translation] > .bp-editorial-title { font-size:.75rem; margin-bottom:.1rem; color:light-dark(#475569,#cbd5e1); text-transform:uppercase; letter-spacing:.04em; }
.bp-editorial[data-kind=translation] > .bp-editorial-content { font-size:.95em; }
.bp-editorial[data-kind=restatement] { border-left-color:light-dark(#4d7c0f,#bef264); }
.bp-editorial[data-kind=restatement] > .bp-editorial-title { color:light-dark(#3f6212,#d9f99d); }
.bp-editorial[data-kind=strengthening] { border-left-color:light-dark(#15803d,#86efac); }
.bp-editorial[data-kind=strengthening] > .bp-editorial-title { color:light-dark(#166534,#bbf7d0); }
.bp-editorial[data-kind=outOfScope] { border-left-style:dashed; }
.bp-correspondence-warning { font-size:.8rem; font-weight:600; color:light-dark(#9a3412,#fdba74); }
"##

def badge (cls text : String) (extra : Array (String × String) := #[]) : Output.Html :=
  .tag "span" (#[("class", s!"bp-badge {cls}")] ++ extra) (.text true text)

def Annotation.badges (a : Annotation) : Array Output.Html := Id.run do
  let mut out : Array Output.Html := #[]
  if let some m := a.missing then out := out.push (badge "bp-badge-missing" s!"missing: {m.key}")
  out := out.push (badge "bp-badge-review" a.review.label #[("data-review", a.review.state)])
  return out

def Annotation.badgeText (a : Annotation) : String :=
  let parts : Array String :=
    (a.missing.map fun m => s!"missing: {m.key}").toArray ++ #[a.review.label]
  " (" ++ String.intercalate "; " parts.toList ++ ")"

def render (a : Annotation) (contents : Array Output.Html) : Output.Html :=
  open Output.Html in
  {{<aside class="bp-editorial" data-kind={{a.kind.key}} data-review={{a.review.state}} aria-label={{a.kind.title}}>
    <div class="bp-editorial-title">
      <span class="bp-editorial-kind">{{.text true a.kind.title}}</span>
      {{.seq a.badges}}
    </div>
    <div class="bp-editorial-content">{{.seq contents}}</div>
  </aside>}}

block_extension Block.editorial (kindKey review missing : String) where
  data := toJson (Annotation.ofStrings kindKey review missing)
  extraCss := [css]
  traverse _ _ _ := pure none
  toHtml := some fun _ goB _ raw blocks => do
    let .ok ann := fromJson? (α := Annotation) raw
      | Verso.reportError "Malformed editorial annotation"
        return .empty
    return render ann (← blocks.mapM goB)
  toTeX := some fun _ goB _ raw blocks => do
    let .ok ann := fromJson? (α := Annotation) raw
      | Verso.reportError "Malformed editorial annotation"
        return .empty
    let body ← blocks.mapM goB
    return Informal.TeX.quotedBlock (ann.kind.title ++ ann.badgeText) body

/-- Inspect the document tree, not rendered HTML or author-supplied approval flags. True when an
annotation of a kind that owes work (`unformalised`, `gap`, `formalizationTodo`) is present. -/
partial def hasFormalizationTodo : Doc.Block Manual → Bool
  | .other ext children =>
    (ext.name == ``Block.editorial &&
      ((fromJson? (α := Annotation) ext.data).toOption.map (·.kind.owesWork) |>.getD false)) ||
      children.any hasFormalizationTodo
  | .concat bs | .blockquote bs => bs.any hasFormalizationTodo
  | .ul items | .ol _ items => items.any fun item => item.contents.any hasFormalizationTodo
  | .dl items => items.any fun item => item.desc.any hasFormalizationTodo
  | _ => false

/-- Raw directive options: `(review := …)` and `(missing := …)`. -/
structure Config where
  review : String := "unreviewed"
  missing : Option String := none

section
variable {m : Type → Type} [Monad m] [Lean.Elab.MonadInfoTree m] [MonadResolveName m]
    [MonadLiftT CoreM m]
    [MonadEnv m] [MonadError m] [MonadFileMap m] [MonadLog m] [AddMessageContext m] [MonadOptions m]

/-- A short value written either as an identifier (`statement`) or as a string (`"reviewed BS 2026-09-22"`). -/
def word : ValDesc m String where
  description := doc!"a word, as an identifier or a string"
  signature := .String
  get
    | .str s => Pure.pure s.getString
    | .name x => Pure.pure x.getId.eraseMacroScopes.toString
    | other => throwError "Expected an identifier or a string, got {toMessageData other}"

def Config.parse : ArgParse m Config :=
  (fun review missing => { review := review.getD "unreviewed", missing })
    <$> .named `review word true <*> .named `missing word true

instance : FromArgs Config m where
  fromArgs := Config.parse

end

private def expand (kind : Kind) : DirectiveExpanderOf Config
  | cfg, contents => do
    let some review := Review.parse? cfg.review
      | throwError "Invalid (review := …): expected unreviewed or \"reviewed <initials> <date>\", got {cfg.review}"
    let missing ← cfg.missing.mapM fun s => do
      let some v := Missing.parse? s
        | throwError "Invalid (missing := …): expected statement or proof, got {s}"
      pure v
    if kind == .unformalised && missing.isNone then
      throwError "unformalised requires (missing := statement) or (missing := proof)"
    if kind != .unformalised && missing.isSome then
      throwError "(missing := …) is allowed only on unformalised annotations"
    let contents ← contents.mapM elabBlock
    let missingKey := (missing.map Missing.key).getD ""
    ``(Verso.Doc.Block.other
        (Block.editorial $(quote kind.key) $(quote review.label) $(quote missingKey))
        #[$contents,*])

end Informal.Editorial

namespace Informal

/-- Implementation and editorial commentary without mathematical authority. -/
@[directive] def «meta» : DirectiveExpanderOf Editorial.Config := Editorial.expand .meta

/-- Neutral account of missing statements or unsettled correspondence and possible resolutions.
Missing proofs alone use the existing proof status, not this directive. -/
@[directive] def formalizationTodo : DirectiveExpanderOf Editorial.Config :=
  Editorial.expand .formalizationTodo

/-- The paper's item has no formalised counterpart. Requires `(missing := statement)` (no Lean
statement) or `(missing := proof)` (a statement written without proof); the body says the state
and why, and what would settle it. -/
@[directive] def unformalised : DirectiveExpanderOf Editorial.Config := Editorial.expand .unformalised

/-- Deliberately omitted material not needed by the claims retained in scope, by a recorded
decision. Explain what is excluded and why; this does not discharge any mathematical obligation. -/
@[directive] def outOfScope : DirectiveExpanderOf Editorial.Config := Editorial.expand .outOfScope

/-- The paper's claim is false as printed (a wrong sign, factor or normalisation, an inconsistent
display, or a hypothesis the claim needs and the paper does not print); the formalisation states
the corrected version, with the reason. The label itself supplies no evidence. -/
@[directive] def correction : DirectiveExpanderOf Editorial.Config := Editorial.expand .correction

/-- The paper's claim is underspecified; the formalisation fixes one reading and names the
alternatives. -/
@[directive] def interpretation : DirectiveExpanderOf Editorial.Config :=
  Editorial.expand .interpretation

/-- A dictionary entry for one unit whose Lean spelling looks very different from the paper's:
the Lean expression in code, "is the paper's", the paper's notation, a reference. -/
@[directive] def translation : DirectiveExpanderOf Editorial.Config := Editorial.expand .translation

/-- The formalisation states a logically equivalent form of the paper's whole statement. Used
sparingly. -/
@[directive] def restatement : DirectiveExpanderOf Editorial.Config := Editorial.expand .restatement

/-- The formal statement implies the paper's and the converse is not claimed. -/
@[directive] def strengthening : DirectiveExpanderOf Editorial.Config :=
  Editorial.expand .strengthening

/-- The formal statement is weaker than or incomparable with the paper's; the body says what
would close it. -/
@[directive] def gap : DirectiveExpanderOf Editorial.Config := Editorial.expand .gap

end Informal

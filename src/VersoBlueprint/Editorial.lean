import VersoManual
import VersoBlueprint.TeX
import VersoBlueprint.ReviewLedger

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
`formalizationTodo` are the framework's older kinds and remain available.

Besides the directives, the items of a "Relation to the source." section in the docstring of a
declaration a node embeds become boxes of the kinds `translation`, `interpretation`, `correction`
and `meta` (`Block.sourceItem`, `Informal.SourceAnnotations`); their review state comes from the
review ledger (`Informal.ReviewLedger`). -/
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

/-- Whether a human has checked the annotation: an agent's assessment until then. A hand-written
directive is `unreviewed` or `reviewed`; an item taken from a docstring can also have changed since
its last review (`ReviewLedger.Status`). -/
inductive Review where
  | unreviewed
  | reviewed (initials date : String)
  | changedSinceReview
deriving BEq, FromJson, ToJson, Repr

def Review.label : Review → String
  | .unreviewed => "unreviewed"
  | .reviewed initials date => s!"reviewed {initials} {date}"
  | .changedSinceReview => "changed since review"

def Review.state : Review → String
  | .unreviewed => "unreviewed"
  | .reviewed .. => "reviewed"
  | .changedSinceReview => "changed"

def Review.ofStatus : ReviewLedger.Status → Review
  | .unreviewed => .unreviewed
  | .changedSinceReview => .changedSinceReview
  | .reviewed reviewer date => .reviewed reviewer date

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

/-- The node-header badge of a node containing an annotation that owes work. -/
def correspondenceWarning : Output.Html :=
  .tag "span" #[("class", "bp-correspondence-warning")]
    (.text true "Owes work")

def css : String := r##"
/* One design for every annotation: a 3px left rule and a Title-case kind title in the kind's hue,
   the body in the page colour, lowercase badges in one style. Warm hues only for the kinds that
   owe work. Every colour is light-dark(). */
.bp-editorial { margin:1rem 0; padding:.7rem 1rem; border-left:3px solid light-dark(#64748b,#94a3b8); background:light-dark(#f8fafc,#111827); font-style:normal; --bp-kind:light-dark(#64748b,#94a3b8); border-left-color:var(--bp-kind); }
.bp-editorial + .bp-editorial { margin-top:1rem; }
.bp-editorial-title { display:flex; flex-wrap:wrap; align-items:center; gap:.5rem; margin-bottom:.4rem; font-size:.9rem; font-weight:650; line-height:1.4; color:var(--bp-kind); text-transform:none; letter-spacing:0; }
.bp-editorial-kind { font-size:inherit; font-weight:inherit; }
.bp-editorial-content > :first-child { margin-top:0; }
.bp-editorial-content > :last-child { margin-bottom:0; }
.bp-badge, .bp-correspondence-warning { display:inline-block; font-size:.7rem; font-weight:600; line-height:1.4; padding:.05rem .5rem; border-radius:.7rem; border:1px solid transparent; text-transform:none; letter-spacing:.01em; vertical-align:middle; }
.bp-badge-review[data-review=unreviewed] { color:light-dark(#475569,#cbd5e1); background:light-dark(#e2e8f0,#334155); }
.bp-badge-review[data-review=reviewed] { color:light-dark(#166534,#bbf7d0); background:light-dark(#dcfce7,#14532d); }
.bp-badge-review[data-review=changed] { color:light-dark(#92400e,#fde68a); background:light-dark(#fef3c7,#422006); }
.bp-editorial-decl { font-size:.8rem; font-weight:500; color:light-dark(#475569,#cbd5e1); }
.bp-editorial-decl code { font-size:inherit; }
.bp-badge-missing { color:light-dark(#991b1b,#fecaca); background:light-dark(#fee2e2,#450a0a); }
.bp-correspondence-warning { color:light-dark(#9a3412,#fdba74); background:light-dark(#ffedd5,#431407); }
.bp-editorial[data-kind=gap], .bp-editorial[data-kind=formalizationTodo] { --bp-kind:light-dark(#c2410c,#fdba74); }
.bp-editorial[data-kind=unformalised] { --bp-kind:light-dark(#b91c1c,#fca5a5); }
.bp-editorial[data-kind=correction] { --bp-kind:light-dark(#7e22ce,#d8b4fe); }
.bp-editorial[data-kind=interpretation] { --bp-kind:light-dark(#0369a1,#7dd3fc); }
.bp-editorial[data-kind=restatement] { --bp-kind:light-dark(#4d7c0f,#bef264); }
.bp-editorial[data-kind=strengthening] { --bp-kind:light-dark(#15803d,#86efac); }
.bp-editorial[data-kind=translation], .bp-editorial[data-kind=outOfScope], .bp-editorial[data-kind=meta] { --bp-kind:light-dark(#64748b,#94a3b8); }
.bp-editorial[data-kind=outOfScope] { border-left-style:dashed; }
.bp-editorial[data-kind=translation] { margin:.5rem 0; padding:.35rem 1rem; background:transparent; }
.bp-editorial[data-kind=translation] + .bp-editorial[data-kind=translation] { margin-top:.5rem; }
.bp-editorial[data-kind=translation] > .bp-editorial-title { margin-bottom:.15rem; }
"##

def badge (cls text : String) (extra : Array (String × String) := #[]) : Output.Html :=
  .tag "span" (#[("class", s!"bp-badge {cls}")] ++ extra) (.text true text)

/-- The badges of an annotation; with `hideReview`, the review badge is left out (`--hide-review`). -/
def Annotation.badges (a : Annotation) (hideReview : Bool := false) : Array Output.Html := Id.run do
  let mut out : Array Output.Html := #[]
  if let some m := a.missing then out := out.push (badge "bp-badge-missing" s!"missing: {m.key}")
  unless hideReview do
    out := out.push (badge "bp-badge-review" a.review.label #[("data-review", a.review.state)])
  return out

def Annotation.badgeText (a : Annotation) (hideReview : Bool := false) : String :=
  let parts : Array String :=
    (a.missing.map fun m => s!"missing: {m.key}").toArray ++
      (if hideReview then #[] else #[a.review.label])
  if parts.isEmpty then "" else " (" ++ String.intercalate "; " parts.toList ++ ")"

/-- One annotation box. `decl?` names the declaration whose docstring the item comes from, shown
after the kind; `attrs` are extra attributes of the box. -/
def render (a : Annotation) (contents : Array Output.Html) (hideReview : Bool := false)
    (decl? : Option String := none) (attrs : Array (String × String) := #[]) : Output.Html :=
  open Output.Html in
  let reviewAttrs := if hideReview then #[] else #[("data-review", a.review.state)]
  let declHtml : Output.Html :=
    match decl? with
    | some d => {{<span class="bp-editorial-decl"><code>{{.text true d}}</code></span>}}
    | Option.none => .empty
  .tag "aside"
    (#[("class", "bp-editorial"), ("data-kind", a.kind.key)] ++ reviewAttrs ++
      #[("aria-label", a.kind.title)] ++ attrs)
    {{<div class="bp-editorial-title">
        <span class="bp-editorial-kind">{{.text true a.kind.title}}</span>
        {{declHtml}}
        {{.seq (a.badges hideReview)}}
      </div>
      <div class="bp-editorial-content">{{.seq contents}}</div>}}

block_extension Block.editorial (kindKey review missing : String) where
  data := toJson (Annotation.ofStrings kindKey review missing)
  extraCss := [css]
  traverse _ _ _ := pure none
  toHtml := some fun _ goB _ raw blocks => do
    let .ok ann := fromJson? (α := Annotation) raw
      | Verso.reportError "Malformed editorial annotation"
        return .empty
    return render ann (← blocks.mapM goB) (hideReview := ← ReviewLedger.reviewHidden)
  toTeX := some fun _ goB _ raw blocks => do
    let .ok ann := fromJson? (α := Annotation) raw
      | Verso.reportError "Malformed editorial annotation"
        return .empty
    let body ← blocks.mapM goB
    let hide ← ReviewLedger.reviewHidden
    return Informal.TeX.quotedBlock (ann.kind.title ++ ann.badgeText hide) body

/-- An annotation taken from the "Relation to the source." section of a declaration's docstring
(`Informal.SourceRelation`). Its review state is looked up in the review ledger when the page is
generated (`Informal.ReviewLedger`). -/
structure SourceItem where
  /-- The annotation kind that renders the item's label (`translation`, `interpretation`,
  `correction`, or `meta` for a formalisation note). -/
  kind : Kind
  /-- The item's label as the ledger names it (`Translation`, ..., `Formalisation note`). -/
  label : String
  /-- The full name of the declaration: the ledger's `decl`. -/
  decl : String
  /-- The declaration as the box title shows it; empty when the node embeds one declaration. -/
  declLabel : String := ""
  /-- `SourceRelation.itemHash` of the item's text: the ledger's `hash`. -/
  hash : String
  /-- The ledger file (`verso.blueprint.reviewLedger` where the node was elaborated). -/
  ledger : String
deriving BEq, FromJson, ToJson, Repr

/-- The review state of a source item, reporting the ledger's problems once per build. -/
def SourceItem.review {m} [Monad m] [MonadLiftT IO m] [Verso.MonadBuildLog m]
    (item : SourceItem) : m Review := do
  let (entries, problems, firstRead) ← (ReviewLedger.load item.ledger : IO _)
  if firstRead then
    for p in problems do
      Verso.reportError s!"Review ledger {item.ledger}: {p}"
  return Review.ofStatus (ReviewLedger.status entries item.decl item.label item.hash)

block_extension Block.sourceItem (kindKey label decl declLabel hash ledger : String) where
  data := toJson ({ kind := (Kind.ofKey? kindKey).getD .meta, label, decl, declLabel, hash, ledger } :
    SourceItem)
  extraCss := [css]
  traverse _ _ _ := pure none
  toHtml := some fun _ goB _ raw blocks => do
    let .ok item := fromJson? (α := SourceItem) raw
      | Verso.reportError "Malformed docstring annotation"
        return .empty
    let hide ← ReviewLedger.reviewHidden
    let review ← if hide then pure .unreviewed else item.review
    let decl? := if item.declLabel.isEmpty then Option.none else some item.declLabel
    return render { kind := item.kind, review } (← blocks.mapM goB) (hideReview := hide)
      (decl? := decl?) (attrs := #[("data-decl", item.decl), ("data-hash", item.hash)])
  toTeX := some fun _ goB _ raw blocks => do
    let .ok item := fromJson? (α := SourceItem) raw
      | Verso.reportError "Malformed docstring annotation"
        return .empty
    let hide ← ReviewLedger.reviewHidden
    let review ← if hide then pure .unreviewed else item.review
    let ann : Annotation := { kind := item.kind, review }
    let declText := if item.declLabel.isEmpty then "" else s!" [{item.declLabel}]"
    let body ← blocks.mapM goB
    return Informal.TeX.quotedBlock (ann.kind.title ++ declText ++ ann.badgeText hide) body

/-- Whether a block is an annotation box taken from a docstring (`Block.sourceItem`). -/
def isSourceItemBlock : Doc.Block Manual → Bool
  | .other ext _ => ext.name == ``Block.sourceItem
  | _ => false

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

import Lean

/-! Bounded, batch-only evidence from already elaborated blueprint code.
This module does not interpret notation or synthesize replacement instances. -/
open Lean Elab Meta

register_option verso.blueprint.collectOccurrences : Bool := {
  defValue := false
  descr := "Collect bounded contextual term occurrences in blueprint Lean blocks (batch only)"
}

register_option verso.blueprint.maxOccurrences : Nat := {
  defValue := 2000
  descr := "Maximum info-tree nodes inspected per blueprint Lean block"
}

namespace Informal.OccurrenceInventory

structure InstanceSlot where
  index : Nat
  binder : String
  className : Option String
  type : String
  value : String
  isLocal : Bool
  usesLocals : Bool
deriving Inhabited, ToJson, FromJson

structure Occurrence where
  startByte : Option Nat := none
  endByte : Option Nat := none
  syntaxKind : String := ""
  source : String := ""
  synthetic : Bool := false
  kind : String := "term"
  status : String := "resolved"
  parentDecl : Option String := none
  application : String := ""
  type : String := ""
  locals : Array String := #[]
  localsTruncated : Bool := false
  constants : Array String := #[]
  instances : Array InstanceSlot := #[]
deriving Inhabited, ToJson, FromJson

structure Block where
  file : String
  label : Option String
  visible : Bool
  /-- `bounded` means the traversal limit was reached, not a complete inventory. -/
  status : String
  occurrences : Array Occurrence
deriving Inhabited, ToJson, FromJson

initialize inventory : SimplePersistentEnvExtension Block (Array Block) ←
  registerSimplePersistentEnvExtension {
    addEntryFn := Array.push
    addImportedFn := fun arrays => arrays.foldl (· ++ ·) #[]
  }

/-- Includes imported compiled documents; no environment/source scan is performed. -/
def blocks (env : Environment) : Array Block := inventory.getState env

/-- A versioned JSON snapshot, suitable for writing from a document generator. -/
def exportJson (env : Environment) : Json := Json.mkObj [
  ("version", toJson (1 : Nat)), ("coverage", toJson "blueprint Lean blocks; saved term info only"),
  ("blocks", toJson (blocks env))]

private def base (stx : Syntax) (ctx : Option ContextInfo) : Occurrence := {
  startByte := stx.getPos?.map (·.byteIdx)
  endByte := stx.getTailPos?.map (·.byteIdx)
  syntaxKind := stx.getKind.toString
  source := stx.reprint.getD ""
  synthetic := match stx.getHeadInfo with | .original .. => false | _ => true
  parentDecl := ctx.bind (·.parentDecl?.map Name.toString)
}

private def pretty (e : Expr) : MetaM String := do
  return (← ppExpr (← instantiateMVars e)).pretty

private partial def consume (e : Expr) (fuel : Nat) : Option Nat := do
  if fuel == 0 then none else
    let fuel := fuel - 1
    match e with
    | .app f a | .lam _ f a _ | .forallE _ f a _ => consume a (← consume f fuel)
    | .letE _ t v b _ => consume b (← consume v (← consume t fuel))
    | .mdata _ e | .proj _ _ e => consume e fuel
    | _ => some fuel

private def term (ctx : ContextInfo) (ti : TermInfo) : IO Occurrence :=
  ti.runMetaM ctx do
    if (consume ti.expr 2000).isNone then
      return { base ti.stx (some ctx) with status := "expression-budget" }
    let e ← instantiateMVars ti.expr
    if (consume e 2000).isNone then
      return { base ti.stx (some ctx) with status := "expression-budget" }
    let mut slots := #[]
    let mut fnType ← inferType e.getAppFn
    for arg in e.getAppArgs, index in [:e.getAppNumArgs] do
      fnType ← whnf fnType
      if let .forallE name _ body bi := fnType then
        if bi.isInstImplicit then
          let ty ← instantiateMVars (← inferType arg)
          let cls := ty.getAppFn.constName?
          slots := slots.push {
            index, binder := name.toString
            className := cls.filter (isClass (← getEnv)) |>.map Name.toString
            type := ← pretty ty, value := ← pretty arg
            isLocal := (← instantiateMVars arg).isFVar
            usesLocals := (← instantiateMVars arg).hasFVar
          }
        fnType := body.instantiate1 arg
    let mut locals := #[]
    let mut localsTruncated := false
    for d in ti.lctx do
      if !d.isImplementationDetail then
        if locals.size < 32 then
          locals := locals.push s!"{d.userName} : {← pretty d.type}"
        else localsTruncated := true
    return { base ti.stx (some ctx) with
      kind := if ti.isBinder then "binder" else "term"
      status := if e.hasMVar then "unresolved-metavariables" else "resolved"
      application := ← pretty e, type := ← pretty (← inferType e)
      locals, localsTruncated
      constants := e.getUsedConstants.map Name.toString, instances := slots
    }

private structure Walk where
  remaining : Nat
  bounded : Bool := false
  rows : Array Occurrence := #[]

private partial def walk (ctx : Option ContextInfo) (tree : InfoTree) : StateT Walk IO Unit := do
  let s ← get
  if s.remaining == 0 then
    modify fun s => { s with bounded := true }
    return
  modify fun s => { s with remaining := s.remaining - 1 }
  match tree with
  | .context c t => walk (c.mergeIntoOuter? ctx) t
  | .hole _ =>
    modify fun s => { s with rows := s.rows.push { kind := "hole", status := "partial" } }
  | .node info children =>
    let ctx := info.updateContext? ctx
    let row? ← match info with
      | .ofTermInfo ti => do
          if let some ci := ctx then
            try pure (some (← term ci ti))
            catch _ => pure (some { base ti.stx ctx with status := "inspection-failed" })
          else pure (some { base ti.stx ctx with status := "missing-context" })
      | .ofPartialTermInfo ti => pure (some { base ti.stx ctx with status := "partial" })
      | .ofMacroExpansionInfo mi => pure (some { base mi.stx ctx with
          kind := "macro"
          status := "syntax-only"
          application := mi.output.reprint.getD "" })
      | _ => pure none
    if let some row := row? then modify fun s => { s with rows := s.rows.push row }
    for child in children do walk ctx child

/-- Collect in saved contexts, before semantic highlighting discards application arguments.
Ranges use the native parser file map. Synthetic macro records are explicitly marked.
There is no claim that every source syntax node has a term-info counterpart. -/
def collect (file : String) (label : Option String) (visible : Bool)
    (trees : PersistentArray InfoTree) (limit : Nat) : IO Block := do
  let (_, s) ← (trees.forM (walk none)).run { remaining := limit }
  return {
    file, label, visible
    status := if s.bounded then "bounded" else "captured"
    occurrences := s.rows }

end Informal.OccurrenceInventory

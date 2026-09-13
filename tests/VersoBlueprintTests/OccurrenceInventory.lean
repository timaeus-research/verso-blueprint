import VersoBlueprint
open Verso.Genre Verso.Genre.Manual Informal

set_option verso.blueprint.collectOccurrences true

#docs (Manual) occurrenceDoc "Contextual occurrences" :=
:::::::
```internal
namespace InventoryAdd
scoped infixl:65 " ◇ " => Nat.add
end InventoryAdd
namespace InventoryMul
scoped infixl:65 " ◇ " => Nat.mul
end InventoryMul
def hiddenInventoryTerm := Nat.add 1 2
```

:::definition "add-scope"
Same glyph, addition scope.
:::
```lean "add-scope"
section
open scoped InventoryAdd
def inventoryAddition (x y : Nat) := x ◇ y
end
```

:::definition "mul-scope"
Same glyph, multiplication scope.
:::
```lean "mul-scope"
section
open scoped InventoryMul
def inventoryMultiplication (x y : Nat) := x ◇ y
def inventoryConcrete (x y : Nat) := x * y
def inventoryLocal {α : Type} [Mul α] (x y : α) := x * y
def inventoryDirectLocal {α : Type} [Mul α] (x y : α) :=
  Mul.mul x y
abbrev InventoryAlias (α : Type) := Mul α
def inventoryAliasedLocal {α : Type} [InventoryAlias α]
    (x y : α) := Mul.mul x y
end
```
:::::::

open Lean Elab Command

run_cmd do
  if Lean.Elab.inServer.get (← getOptions) then return
  let bs := OccurrenceInventory.blocks (← getEnv)
  unless bs.any (!·.visible) do throwError "hidden code missing"
  let rows := bs.flatMap (·.occurrences)
  for (decl, operation) in [("inventoryAddition", "Nat.add"),
      ("inventoryMultiplication", "Nat.mul")] do
    unless rows.any (fun r => r.parentDecl == some decl &&
        r.constants.contains operation && r.source.contains '◇' &&
        r.startByte.isSome && r.endByte.isSome) do
      throwError "missing contextual operation for {decl}"
  unless rows.any (fun r => r.parentDecl == some "inventoryLocal" &&
      r.instances.any (fun s => s.usesLocals && s.className == some "HMul")) do
    throwError "missing local-containing multiplication instance"
  unless rows.any (fun r => r.parentDecl == some "inventoryDirectLocal" &&
      r.instances.any (fun s => s.isLocal && s.className == some "Mul")) do
    throwError "missing direct local instance argument"
  unless rows.any (fun r => r.parentDecl == some "inventoryAliasedLocal" &&
      r.instances.any (fun s => s.isLocal && s.className == some "Mul" &&
        s.type.startsWith "InventoryAlias")) do
    throwError "class alias lost its class identity or original display"
  let source := (← getFileMap).source
  let mut checkedRanges := 0
  for r in rows do
    if !r.synthetic && r.source.trimAscii.toString == "x ◇ y" then
      let some a := r.startByte | throwError "missing original start position"
      let some b := r.endByte | throwError "missing original end position"
      unless (String.fromUTF8! (source.toUTF8.extract a b)).trimAscii.toString ==
          "x ◇ y" do
        throwError "occurrence range does not recover the source application"
      checkedRanges := checkedRanges + 1
  unless checkedRanges >= 2 do throwError "original application ranges not checked"
  unless rows.any (fun r => r.parentDecl == some "inventoryConcrete" &&
      r.instances.any (!·.isLocal)) do
    throwError "missing concrete instance argument"
  unless rows.any (fun r => r.source.contains '◇') do
    throwError "source notation lost"
  let json := OccurrenceInventory.exportJson (← getEnv)
  unless (json.getObjVal? "blocks").isOk do throwError "export missing blocks"
  let decoded : Except String (Array OccurrenceInventory.Block) := fromJson? (toJson bs)
  match decoded with
  | .error e => throwError "round trip: {e}"
  | .ok ds => unless ds.size == bs.size do throwError "round trip lost blocks"

run_cmd do
  let partialTree := InfoTree.hole ⟨`inventoryHole⟩
  let b ← liftIO <| OccurrenceInventory.collect "test" none false
    (PersistentArray.empty.push partialTree) 10
  unless b.occurrences.any (·.status == "partial") do throwError "partial info lost"
  let b ← liftIO <| OccurrenceInventory.collect "test" none true
    (PersistentArray.empty.push partialTree) 0
  unless b.status == "bounded" do throwError "budget not reported"

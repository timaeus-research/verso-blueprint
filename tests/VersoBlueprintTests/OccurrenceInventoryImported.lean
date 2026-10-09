import VersoBlueprintTests.OccurrenceInventory
open Lean Elab Command Informal

run_cmd do
  let bs := OccurrenceInventory.blocks (← getEnv)
  unless bs.any (fun b => b.occurrences.any (fun r =>
      r.parentDecl == some "inventoryAddition" && r.constants.contains "Nat.add")) do
    throwError "compiled import lost contextual occurrence evidence"

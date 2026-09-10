import VersoBlueprint.Informal.Block.Render
import VersoBlueprint.Informal.Block.Store
import VersoBlueprint.ReaderDocument
import VersoBlueprintTests.Blueprint.Support
import VersoBlueprintTests.Editorial

open Informal Lean
open Verso.VersoBlueprintTests.Blueprint.Support

private def reader : Reader.Context := {
  codename := "fixture", commit := "abc123", baseUrl := "https://example.org/"
}

private def node : BlockData := {
  kind := .theorem, label := `fixture, count := 1
  readerContext := some reader
  paperIdentity := some { label := "Theorem 3", href := "https://example.org/paper#page=2" }
  hasFormalizationTodo := true
}

/-- info: true -/
#guard_msgs in
#eval show IO Bool from pure (Reader.encode "α & x" == "%CE%B1%20%26%20x")

/-- info: true -/
#guard_msgs in
#eval show IO Bool from pure (Reader.labelString (Name.mkSimple "thm:main") == "thm:main")

/-- info: true -/
#guard_msgs in
#eval show IO Bool from do
  let block := Reader.Block.readerParagraph { reader, key := "reader-p-1", quote := "A paragraph" }
  let data ← IO.ofExcept (fromJson? (α := Reader.Paragraph) block.data)
  return data.quote == "A paragraph"

/-- info: true -/
#guard_msgs in
#eval show IO Bool from do
  let stored ← IO.ofExcept (fromJson? (α := BlockOccurrence) (toJson node.toOccurrence))
  let restored := mergeBlockOccurrences { node with
    paperIdentity := none, readerContext := none, hasFormalizationTodo := false }
    (RenderNode.ofBlockData node |>.resolve stored)
  return restored.paperIdentity.map (·.label) == some "Theorem 3" &&
    restored.readerContext.map (·.commit) == some "abc123" && restored.hasFormalizationTodo

/-- info: true -/
#guard_msgs in
#eval show IO Bool from do
  let html := (renderInformalBlockHtml node (.forBlock node "1.1") #[]).asString
  let proof := { node with isProof := true }
  let proofHtml := (renderInformalBlockHtml proof (.forBlock proof "1.1") #[]).asString
  return appearsBefore html "bp_paper_ref_badge" "bp_extras" &&
    hasSubstr html "Theorem 3" && hasSubstr html "bp_issue_chip" &&
    hasSubstr html "Informal.Block.informal" &&
    !(hasSubstr proofHtml "bp_paper_ref_badge") && hasSubstr proofHtml "bp_issue_chip"

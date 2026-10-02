import VersoBlueprint.Informal.Block.Render
import VersoBlueprint.Informal.Block.Store
import VersoBlueprint.ReaderDocument
import VersoBlueprintTests.Blueprint.Support
import VersoBlueprintTests.Editorial
import VersoBlueprintTests.ReaderImported

open Informal Lean
open Verso Genre Manual
open Verso.VersoBlueprintTests.Blueprint.Support

private def identityImpls : ExtensionImpls := extension_impls%

/-- info: true -/
#guard_msgs in
#eval show IO Bool from do
  let files ← buildManualPreviewDataFiles identityImpls importedIdentityDoc
  let entry := files.manifest.previews.find? fun entry => entry.label == Name.mkSimple "identity.imported"
  let nested := files.manifest.previews.find? fun entry => entry.label == Name.mkSimple "identity.nested"
  let unnumbered := files.manifest.previews.find? fun entry => entry.label == Name.mkSimple "identity.unnumbered"
  pure <| (entry.bind (·.paperIdentity)).map (·.label) == some "Definition 2" &&
    (nested.bind (·.paperIdentity)).map (·.label) == some "Lemma 3" &&
    unnumbered.isSome && (unnumbered.bind (·.paperIdentity)).isNone

/-- info: true -/
#guard_msgs in
#eval! do
  let html ← renderManualDocHtmlString identityImpls importedIdentityDoc
  pure <| countSubstr html "bp_paper_ref_badge" == 2 &&
    countSubstr html "<span class=\"bp_paper_ref_key\">source</span>" == 2 &&
    hasSubstr html "Definition 2 ↗" && hasSubstr html "Lemma 3 ↗" &&
    hasSubstr html "source/paper.pdf#page=3" && hasSubstr html "page 3"

private def reader : Reader.Context := {
  codename := "fixture", commit := "abc123", baseUrl := "https://example.org/"
}

private def node : BlockData := {
  kind := .statement .theorem, label := `fixture, count := 1
  readerContext := some reader
  paperIdentity := some { label := "Theorem 3", href := "https://example.org/paper#page=2" }
  hasFormalizationTodo := true
}

/-- info: true -/
#guard_msgs in
#eval show IO Bool from do
  let entry : PreviewManifest.Entry := {
    key := "identity", targetKind := .block, label := `identity,
    facet := .statement, title := "Identity", paperIdentity := node.paperIdentity }
  let restored ← IO.ofExcept (fromJson? (α := PreviewManifest.Entry) (toJson entry))
  return restored.blockData.paperIdentity == node.paperIdentity

/-- info: true -/
#guard_msgs in
#eval show IO Bool from pure (
  !({ label := " ", href := "paper.pdf" } : Reader.PaperIdentity).isValid &&
  !({ label := "Lemma 1", href := "javascript:alert(1)" } : Reader.PaperIdentity).isValid &&
  !({ label := "Lemma 1", href := "paper.pdf", pdfHref := "data:text/html,bad" } : Reader.PaperIdentity).isValid &&
  (Reader.paper { label := "Lemma 1", href := "javascript:alert(1)" }).asString.isEmpty)

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
  let stored ← IO.ofExcept (fromJson? (α := StoredBlockData) (toJson node.toStoredData))
  let restored := (mergeStoredBlockData { node.toStoredData with
    paperIdentity := none, readerContext := none, hasFormalizationTodo := false } stored).toBlockData
  return restored.paperIdentity.map (·.label) == some "Theorem 3" &&
    restored.readerContext.map (·.commit) == some "abc123" && restored.hasFormalizationTodo

/-- info: true -/
#guard_msgs in
#eval show IO Bool from do
  let html := (renderInformalBlockHtml node (.forBlock node "1.1") #[]).asString
  let proof := { node with kind := .proof }
  let proofHtml := (renderInformalBlockHtml proof (.forBlock proof "1.1") #[]).asString
  return appearsBefore html "bp_paper_ref_badge" "bp_extras" &&
    hasSubstr html "Theorem 3" && hasSubstr html "bp_issue_chip" &&
    hasSubstr html "Informal.Block.informal" &&
    hasSubstr html (Reader.encode "Source: Theorem 3") && !(hasSubstr html (Reader.encode "Paper: ")) &&
    !(hasSubstr proofHtml "bp_paper_ref_badge") && hasSubstr proofHtml "bp_issue_chip"

private def sourceFixture : Source.Ref := {
  document := "paper"
  spans := #[
    { page := "5", pdf := some { path := "source/pages/page-5.pdf" } },
    { page := "6", pdf := some { path := "source/pages/page-6.pdf" } }
  ]
}

private def readerInput : Reader.Input := {
  reader
  blobBase := "https://example.org/blob/abc123/fixture/"
  pdfUrl := "https://example.org/paper.pdf"
  sources := #[]
  nodes := #[]
}

/-- info: true -/
#guard_msgs in
#eval show IO Bool from do
  let unmapped := Reader.enrich readerInput node
  let mapped := Reader.enrich { readerInput with nodes := #[{
    name := "fixture", label := "Lemma 7", href := "source/paper.pdf#page=8" }] } node
  return unmapped.paperIdentity == node.paperIdentity &&
    mapped.paperIdentity.map (·.label) == some "Lemma 7"

/-- error: Label invalid_identity has invalid paperIdentity metadata: a nonempty label and safe source URLs are required -/
#guard_msgs in
#docs (Manual) invalidIdentityDoc "Invalid identity" :=
:::::::
:::theorem "invalid_identity"
%%%
paperIdentity := some { label := "Theorem 1", href := "javascript:alert(1)" }
%%%
An unsafe source URL is rejected during elaboration.
:::
:::::::

/-- info: true -/
#guard_msgs in
#eval show IO Bool from do
  let oldContext := Json.mkObj [
    ("codename", toJson "fixture"), ("commit", toJson "abc123"),
    ("sourcePin", toJson ""),
    ("baseUrl", toJson "https://example.org/")]
  let parsed ← IO.ofExcept (fromJson? (α := Reader.Context) oldContext)
  return parsed.sourceBaseUrl.isEmpty

/-- info: true -/
#guard_msgs in
#eval show IO Bool from do
  let enriched := Reader.enrich readerInput { node with
    paperIdentity := none, sourceRef := some sourceFixture }
  let stored ← IO.ofExcept (fromJson? (α := StoredBlockData) (toJson enriched.toStoredData))
  let html := (renderInformalBlockHtml enriched (.forBlock enriched "1.1") #[]).asString
  return enriched.paperIdentity.isNone && enriched.sourceRef == some sourceFixture &&
    enriched.readerContext.map (·.sourceBaseUrl) == some readerInput.blobBase &&
    stored.readerContext.map (·.sourceBaseUrl) == some readerInput.blobBase &&
    !(hasSubstr html "bp_paper_ref_badge") &&
    hasSubstr html "href=\"https://example.org/blob/abc123/fixture/source/pages/page-5.pdf\"" &&
    hasSubstr html "href=\"https://example.org/blob/abc123/fixture/source/pages/page-6.pdf\"" &&
    hasSubstr html "Page 5 (PDF)" && hasSubstr html "Page 6 (PDF)" &&
    hasSubstr html "data-bp-source-pdf=\"source/pages/page-5.pdf\""

-- Outside reader enrichment, the author/runtime supplies source assets at the
-- site root. Verso's <base> already accounts for nested-page depth.
/-- info: true -/
#guard_msgs in
#eval show IO Bool from do
  let bare := { node with
    paperIdentity := none, readerContext := none,
    sourceRef := some sourceFixture }
  let headers : HeaderExtras := {
    source? := renderSourceHeaderExtra? #[sourceFixture] (sourceLinkBase none 2)
  }
  let html := (renderInformalBlockHtml bare
    (.forBlock bare "1.1" (headerExtras := headers)) #[]).asString
  return hasSubstr html "href=\"source/pages/page-5.pdf\"" &&
    !(hasSubstr html "href=\"../../source/pages/page-5.pdf\"") &&
    sourceLinkBase none 0 == "" &&
    sourceLinkBase none 2 == "" &&
    sourceLinkBase (some reader) 2 == "" &&
    sourceLinkBase (some { reader with sourceBaseUrl := readerInput.blobBase }) 2 ==
      readerInput.blobBase

/-- info: true -/
#guard_msgs in
#eval show IO Bool from do
  let textOnly : Source.Ref := { document := "notes", spans := #[{ page := "7" }] }
  let bare := { node with
    paperIdentity := none, readerContext := none,
    sourceRef := some textOnly }
  let html := (renderInformalBlockHtml bare (.forBlock bare "1.1") #[]).asString
  return hasSubstr html "page 7" && !(hasSubstr html "class=\"bp_source_ref_pdf\"")

/-- info: true -/
#guard_msgs in
#eval show IO Bool from pure (
  sourcePdfHref? "../../" "https://example.org/p.pdf" == some "https://example.org/p.pdf" &&
  sourcePdfHref? "../../" "http://example.org/p.pdf" == some "http://example.org/p.pdf" &&
  sourcePdfHref? "../../" "/assets/p.pdf" == some "/assets/p.pdf" &&
  sourcePdfHref? readerInput.blobBase "javascript:alert(1)" == none &&
  sourcePdfHref? "" "data:text/html,bad" == none &&
  sourcePdfHref? "" "java\nscript:alert(1)" == none &&
  sourcePdfHref? "javascript:alert(1)/" "page.pdf" == none)

/-- info: true -/
#guard_msgs in
#eval show IO Bool from do
  let source : Source.Ref := { document := "paper", spans := #[
    { page := "12", pdf := some { path := "/source/paper.pdf#page=16" } },
    { page := "A", pdf := some { path := "/source/paper.pdf#nameddest=appendix" } },
    { page := "12", pdf := some { path := "/source/pages/page-12.pdf" } }
  ] }
  let sourced := { node with sourceRef := some source }
  let html := (renderInformalBlockHtml sourced (.forBlock sourced "1.1") #[]).asString
  return hasSubstr html "paper.pdf#page=16" &&
    hasSubstr html "paper.pdf#nameddest=appendix" &&
    hasSubstr html "pages/page-12.pdf\"" &&
    !(hasSubstr html "#page=12")

/-- info: true -/
#guard_msgs in
#eval show IO Bool from do
  let escaped : Source.Ref := { document := "paper", spans := #[
    { page := "5", pdf := some { path := "https://example.org/p.pdf?name=\"quoted\"&x=1" } }
  ] }
  let bare := { node with
    paperIdentity := none, readerContext := none,
    sourceRef := some escaped }
  let html := (renderInformalBlockHtml bare (.forBlock bare "1.1") #[]).asString
  return hasSubstr html "name=&quot;quoted&quot;&amp;x=1" &&
    !(hasSubstr html "name=\"quoted\"")

import VersoBlueprint.Reader
import VersoBlueprint.Informal.Block

open Verso Doc Genre Manual Lean

namespace Informal.Reader

structure NodeIdentity where
  name : String
  label : String
  href : String
  spanOnly : Bool := false
deriving FromJson

structure SourceUrl where
  name : String
  url : String
deriving FromJson

structure Input where
  reader : Context
  blobBase : String
  pdfUrl : String
  sources : Array SourceUrl
  nodes : Array NodeIdentity
deriving FromJson

structure Paragraph where
  reader : Context
  key : String
  quote : String
  isSection : Bool := false
deriving FromJson, ToJson

block_extension Block.readerParagraph (data : Paragraph) where
  data := toJson data
  traverse id raw _ := do
    let .ok data := fromJson? (α := Paragraph) raw | return none
    let _ ← externalTag id (← read).path data.key
    return none
  extraCss := [css]
  toHtml := some fun goI _goB id raw blocks => do
    let .ok data := fromJson? (α := Paragraph) raw | return .empty
    let st ← Verso.Doc.Html.HtmlT.state
    let ctx ← Verso.Doc.Html.HtmlT.context
    let target := data.reader.baseUrl ++ String.intercalate "/" ctx.path.toList ++
      (if ctx.path.isEmpty then "" else "/") ++ "#" ++ data.key
    let link := issue data.reader data.key target ("Quote: " ++ data.quote)
      (if data.isSection then "⚑ section" else "⚑")
    let mut contents := #[]
    for block in blocks do
      if let .para inlines := block then
        contents := contents ++ (← inlines.mapM goI)
    return .tag "p" (st.htmlId id |>.push ("class", "bp_reader_paragraph"))
      (.seq (contents.push link))
  toTeX := some fun _ goB _ _ blocks => do
    return .seq (← blocks.mapM goB)

private partial def inlineText : Doc.Inline Manual → String
  | .text s | .code s | .math _ s => s
  | .linebreak _ => " "
  | .emph xs | .bold xs | .concat xs | .other _ xs | .link xs _ | .footnote _ xs =>
    String.join (xs.toList.map inlineText)
  | .image alt _ => alt

private def enrich (input : Input) (data : BlockOccurrence) : BlockOccurrence := Id.run do
  let mut identity : Option PaperIdentity := none
  if let some entry := input.nodes.find? (·.name == labelString data.label) then
    let source := data.sourceRef
    let pdf := source.bind (·.spans[0]?) |>.bind (·.pdf) |>.map (input.blobBase ++ ·.path) |>.getD ""
    if entry.spanOnly then
      if let some ref := source then
        let pages := ref.spans.filterMap (·.page)
        let base := (input.sources.find? (·.name == ref.document)).map (·.url) |>.getD input.pdfUrl
        let href := if base.isEmpty then pdf else base ++ "#page=" ++ (pages[0]?.getD "")
        if !pages.isEmpty && !href.isEmpty then
          identity := some { label := (if pages.size == 1 then "p. " else "pp. ") ++
            String.intercalate ", " pages.toList, href, pdfHref := pdf }
    else if !entry.label.isEmpty then
      let href := if entry.href.isEmpty then pdf else entry.href
      if !href.isEmpty then
        identity := some { label := entry.label, href, pdfHref := pdf }
  return { data with paperIdentity := identity, readerContext := some input.reader }

private partial def prepareBlock (input : Input) (insideNode : Bool)
    (block : Doc.Block Manual) : StateM Nat (Doc.Block Manual) := do
  match block with
  | .other ext children =>
    if ext.name == ``Block.informal then
      let .ok data := fromJson? (α := BlockOccurrence) ext.data | return block
      return .other { ext with data := toJson (enrich input data) }
        (← children.mapM (prepareBlock input true))
    else
      return .other ext (← children.mapM (prepareBlock input true))
  | .para xs =>
    if insideNode then return block
    let n ← get
    modify (· + 1)
    let quote := String.join (xs.toList.map inlineText)
    let data : Paragraph := { reader := input.reader, key := s!"reader-p-{n}", quote := String.ofList (quote.toList.take 120) }
    return .other (Block.readerParagraph data) #[block]
  | .concat bs => return .concat (← bs.mapM (prepareBlock input insideNode))
  | .blockquote bs => return .blockquote (← bs.mapM (prepareBlock input insideNode))
  | .ul items => return .ul (← items.mapM fun ⟨bs⟩ => return ⟨← bs.mapM (prepareBlock input insideNode)⟩)
  | .ol n items => return .ol n (← items.mapM fun ⟨bs⟩ => return ⟨← bs.mapM (prepareBlock input insideNode)⟩)
  | .dl items => return .dl (← items.mapM fun ⟨term, bs⟩ => return ⟨term, ← bs.mapM (prepareBlock input insideNode)⟩)
  | .code _ => return block

private partial def preparePart (input : Input) (part : Part Manual) : StateM Nat (Part Manual) := do
  let n ← get
  modify (· + 1)
  let sectionLink : Paragraph := { reader := input.reader, key := s!"reader-section-{n}", quote := part.titleString, isSection := true }
  return { part with
    content := #[.other (Block.readerParagraph sectionLink) #[]] ++ (← part.content.mapM (prepareBlock input false))
    subParts := ← part.subParts.mapM (preparePart input) }

/-- Resolve anchor data before Verso traversal, so native renderers and previews share it. -/
def prepare (text : Part Manual) : IO (Part Manual) := do
  if !(← System.FilePath.pathExists "paper-refs.json") &&
      !(← System.FilePath.pathExists "anchor/paper-refs.json") then return text
  let result ← IO.Process.output { cmd := "python3", args := #["../scripts/anchor_render_data.py", "."] }
  if result.exitCode != 0 then throw <| IO.userError result.stderr
  let input ← IO.ofExcept (Json.parse result.stdout >>= fromJson? (α := Input))
  return (preparePart input text).run' 0

end Informal.Reader

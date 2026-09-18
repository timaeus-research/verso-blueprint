/-
Copyright (c) 2026 Timaeus. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
-/

import VersoBlueprint.Informal.Block

/-!
# Which namespaces were open: a legend for rendered Lean names

An external declaration (`(lean := "…")`) is rendered in the Lean context of the chapter file that
references it, so an `open N` in that file shortens the names inside the rendered signatures and
bodies. Each snapshot records the namespaces that were open (`ExternalRef.openNamespaces`). The
preparation pass `prepare` reads them back off the finished document: an HTML page whose linked
declarations all saw the same namespaces gets one legend block at the top; a page whose
declarations disagree gets the namespaces on every rendered row instead (`legendInKicker`). The
pass takes the renderer's `htmlDepth` so that it knows which parts share a page.
Nothing here is authored by hand, so the legend cannot drift from the rendering.
-/

open Verso Doc Genre Manual Lean

namespace Informal.LeanNamesLegend

def css : String := r#"
.bp_lean_names_legend { font-size: .85em; opacity: .8; margin: .25rem 0 1rem 0; }
.bp_lean_names_legend code { font-size: .95em; }
.bp_external_decl_open_namespaces { font-size: .85em; opacity: .8; margin-left: .75em; }
"#

private def namesHtml (names : Array Name) : Verso.Output.Html :=
  let items := names.toList.map fun n =>
    Verso.Output.Html.tag "code" #[] (.text true n.toString)
  match items with
  | [] => .empty
  | [x] => x
  | x :: xs => .seq (x :: (xs.map fun y => Verso.Output.Html.seq #[.text true ", ", y])).toArray

block_extension Block.leanNamesLegend (names : Array Name) where
  data := toJson names
  traverse _ _ _ := pure none
  extraCss := [css]
  toHtml := some fun _goI _goB _id raw _blocks => do
    let .ok (names : Array Name) := fromJson? raw | return .empty
    if names.isEmpty then return .empty
    return .tag "p" #[("class", "bp_lean_names_legend")] <| .seq #[
      .text true "Lean names in this section are shown relative to ",
      namesHtml names,
      .text true "."]
  toTeX := some fun _ _ _ _ _ => pure .empty

/-- The display namespaces of every external declaration reachable from a block, in order. -/
private partial def openLists : Doc.Block Manual → Array (List Name)
  | .other ext children =>
    let here : Array (List Name) :=
      if ext.name == ``Informal.Block.informal then
        match fromJson? (α := BlockData) ext.data with
        | .ok data =>
          match data.codeData with
          | some (.external decls) => decls.map (·.displayOpenNamespaces)
          | _ => #[]
        | .error _ => #[]
      else #[]
    here ++ children.flatMap openLists
  | .concat bs | .blockquote bs => bs.flatMap openLists
  | .ul items | .ol _ items => items.flatMap fun ⟨bs⟩ => bs.flatMap openLists
  | .dl items => items.flatMap fun ⟨_, bs⟩ => bs.flatMap openLists
  | _ => #[]

/-- Ask every rendered declaration row of a block to state its open namespaces. -/
private partial def markKicker : Doc.Block Manual → Doc.Block Manual
  | .other ext children =>
    let ext :=
      if ext.name == ``Informal.Block.informal then
        match fromJson? (α := BlockData) ext.data with
        | .ok data =>
          match data.codeData with
          | some (.external decls) =>
            let decls := decls.map fun r => { r with legendInKicker := true }
            { ext with data := toJson { data with codeData := some (.external decls) } }
          | _ => ext
        | .error _ => ext
      else ext
    .other ext (children.map markKicker)
  | .concat bs => .concat (bs.map markKicker)
  | .blockquote bs => .blockquote (bs.map markKicker)
  | .ul items => .ul (items.map fun ⟨bs⟩ => ⟨bs.map markKicker⟩)
  | .ol n items => .ol n (items.map fun ⟨bs⟩ => ⟨bs.map markKicker⟩)
  | .dl items => .dl (items.map fun ⟨t, bs⟩ => ⟨t, bs.map markKicker⟩)
  | b => b

/-- The display namespaces of every declaration in a part and, recursively, its subparts. -/
private partial def subtreeLists (part : Part Manual) : Array (List Name) :=
  part.content.flatMap openLists ++ part.subParts.flatMap subtreeLists

/-- One legend block at the top when the lists agree and are nonempty; the rows marked when they
disagree; untouched when there is nothing to say. -/
private def withLegend (content : Array (Doc.Block Manual)) (lists : Array (List Name)) :
    Array (Doc.Block Manual) :=
  match lists[0]? with
  | Option.none => content
  | some first =>
    if lists.all (· == first) then
      if first.isEmpty then content else #[.other (Block.leanNamesLegend first.toArray) #[]] ++ content
    else
      content.map markKicker

/--
`pagesBelow` is the number of part levels below this one that still get their own HTML page
(Verso's `htmlDepth`, counted down while descending). When it reaches `0`, or the part carries
`htmlSplit := .never`, the part and its whole subtree render on one page: a single legend for the
subtree goes at the top of the part when the subtree agrees, and otherwise each nested part is
handled on its own. When the children are separate pages, only the part's own content is this
page's, and the children recurse.
-/
private partial def preparePart (pagesBelow : Nat) (part : Part Manual) : Part Manual :=
  let inline := pagesBelow == 0 ||
    (part.metadata.map (fun m => m.htmlSplit == HtmlSplitMode.never) |>.getD false)
  if inline then
    let all := subtreeLists part
    match all[0]? with
    | Option.none => part
    | some first =>
      if all.all (· == first) then
        { part with content := withLegend part.content all }
      else
        { part with
          content := withLegend part.content (part.content.flatMap openLists)
          subParts := part.subParts.map (preparePart 0) }
  else
    { part with
      content := withLegend part.content (part.content.flatMap openLists)
      subParts := part.subParts.map (preparePart (pagesBelow - 1)) }

/--
Attach the open-namespace legends to a document before rendering: one legend block at the top of
each HTML page whose linked declarations were rendered with the same open namespaces, and per-row
notes where a page's declarations differ. `htmlDepth` must be the value the renderer uses (Verso's
default is `2`), so that the pass knows which parts share a page. Apply it to the document passed
to the generator, e.g.
`blueprintMainWithPreviewData (Informal.LeanNamesLegend.prepare (htmlDepth := 1) (%doc Blueprint))
args … (config := { htmlDepth := 1 })`.
-/
def prepare (text : Part Manual) (htmlDepth : Nat := 2) : Part Manual := preparePart htmlDepth text

end Informal.LeanNamesLegend

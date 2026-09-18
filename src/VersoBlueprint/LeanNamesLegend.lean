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
preparation pass `prepare` reads them back off the finished document: a part whose linked
declarations all saw the same namespaces gets one legend block at the top; a part whose
declarations disagree gets the namespaces on every rendered row instead (`legendInKicker`).
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
      .text true "; declaration headers show the full name."]
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

private partial def preparePart (part : Part Manual) : Part Manual :=
  let lists := part.content.flatMap openLists
  let content :=
    match lists[0]? with
    | Option.none => part.content
    | some first =>
      if lists.all (· == first) then
        if first.isEmpty then part.content
        else #[.other (Block.leanNamesLegend first.toArray) #[]] ++ part.content
      else
        part.content.map markKicker
  { part with content, subParts := part.subParts.map preparePart }

/--
Attach the open-namespace legends to a document before rendering: one legend block per part whose
linked declarations were rendered with the same open namespaces, and per-row notes where they
differ. Apply it to the document passed to the generator, e.g.
`blueprintMainWithPreviewData (Informal.LeanNamesLegend.prepare (%doc Blueprint)) args …`.
-/
def prepare (text : Part Manual) : Part Manual := preparePart text

end Informal.LeanNamesLegend

/-
Copyright (c) 2026 Lean FRO LLC. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
-/

import VersoManual
import VersoBlueprint.Environment
import VersoBlueprint.ExternalDeclRender
import VersoBlueprint.Informal.LeanCodeLink
import VersoBlueprint.Informal.Uses
import VersoBlueprint.Lib.ExtensionDecode
import VersoBlueprint.LeanNameParsing
import VersoBlueprint.Resolve

/-!
The inline role `{decl}` for a Lean declaration named in prose:

```
the clause is `CommutesWithSmoothMorphisms` ...           -- plain code
the clause is {decl}`CommutesWithSmoothMorphisms` ...     -- a link to the node presenting it
```

The name is written as Lean would read it in the chapter file: relative to the namespaces the
file opens, or fully qualified. It renders as inline code linking to the canonical node's
rendering of the declaration (`Resolve.canonicalDeclDomainName`), the target the constants of
rendered declaration code link to, with the declaration's code as hover preview.
`{decl Other.name}`text`` resolves `Other.name` and displays `text`.

Resolution, in order:

0. Inside a node's statement or proof, the declarations that node presents come first: the one
   whose full name is the name or ends with `.` followed by it, if there is exactly one. So `map` in
   the node presenting `AnalyticSpace.ResolutionAssignment.map` names that field, whatever `map`
   means in the chapter's scope.
1. The name is resolved at elaboration, as an identifier in the chapter's scope. Of the constants it
   denotes, the one presented at some node is taken (several such constants are an error).
2. When it denotes no constant at all, it is matched against the declarations presented at nodes:
   those whose full name is the written name or ends with `.` followed by it. If there are several,
   only those inside a namespace the chapter opens (or the current namespace) are kept, so that
   `HasSncBoundaries` names `AlgebraicGeometry.Scheme.BlowUpSequence.HasSncBoundaries` in a chapter
   that opens `AlgebraicGeometry` and `AnalyticManifold.FiniteSuccession.HasSncBoundaries` in one
   that opens `AnalyticManifold`. Exactly one must remain.
3. When it denotes exactly one constant that no node presents, and that constant has an entry in
   the published API documentation (`docsHref?`: Lean core, Std, Mathlib and Mathlib's
   dependencies), the code links there.

Anything else is a build error (reported when the HTML is generated, since only then are all nodes
known), so that prose cannot keep naming a declaration that no node presents any more.
-/

namespace Informal

open Lean Elab
open Verso Doc Elab
open Verso.Genre Manual
open Verso.ArgParse

/-- What the `{decl}` role recorded at elaboration. -/
structure DeclRefData where
  /-- The code as written, which is displayed. -/
  written : String
  /-- The name resolved, when given apart from the code (`{decl Name}`code``); else empty. -/
  name : String := ""
  /-- The declarations of the node whose statement or proof contains the reference. -/
  enclosingDecls : Array Name := #[]
  /-- The constants the name denotes in the chapter's scope. -/
  candidates : Array Name := #[]
  /-- The API documentation URL of the only candidate, when it has one. -/
  docsHref? : Option String := none
  /-- The namespaces open at the reference (and the current namespace and its prefixes). -/
  openNamespaces : Array Name := #[]
  /-- The source file of the reference, for error messages. -/
  file : String := ""
  /-- The 0-based line and column (LSP convention) of the reference in `file`. -/
  line : Nat := 0
  column : Nat := 0
deriving ToJson, FromJson, Repr, Quote

/-- How a `{decl}` reference resolved against the traversal state. -/
inductive DeclRefTarget where
  /-- The node presenting `decl` renders it at `href`. -/
  | node (decl : String) (href : String)
  /-- No node presents the declaration; it is documented at `href`. -/
  | docs (href : String)
  | error (message : String)
deriving Repr, BEq

/-- The name to resolve: the explicit one, else the code as written. -/
def DeclRefData.refName (data : DeclRefData) : String :=
  if data.name.isEmpty then data.written else data.name

/-- Whether the full name `decl` is `written` or ends with `.written`. -/
def DeclRefData.suffixMatches (written decl : String) : Bool :=
  decl == written || decl.endsWith ("." ++ written)

/--
Resolve a `{decl}` reference, given the full names of the declarations presented at nodes
(`nodeDecls`) and their link targets (`declHref`).
-/
def DeclRefData.resolve (data : DeclRefData) (nodeDecls : Array String)
    (declHref : String → Option String) : DeclRefTarget :=
  let inNode := data.enclosingDecls.filterMap fun d =>
    if suffixMatches data.refName d.toString then (declHref d.toString).map (d.toString, ·)
    else none
  if let #[(decl, href)] := inNode then .node decl href else
  let withNode := data.candidates.filterMap fun c =>
    (declHref c.toString).map (c.toString, ·)
  match withNode.toList with
  | [(decl, href)] => .node decl href
  | _ :: _ :: _ =>
    .error s!"{data.refName} denotes several declarations presented at nodes: \
      {", ".intercalate (withNode.toList.map (·.1))}"
  | [] =>
    if data.candidates.isEmpty then
      let found := nodeDecls.filter (suffixMatches data.refName)
      let inOpen := found.filter fun d =>
        data.openNamespaces.any fun ns => d.startsWith (ns.toString ++ ".")
      let found := if found.size > 1 && !inOpen.isEmpty then inOpen else found
      match found.toList with
      | [decl] =>
        match declHref decl with
        | some href => .node decl href
        | none => .error s!"{data.refName}: the node presenting {decl} has no anchor for it"
      | [] =>
        .error s!"{data.refName} is not a constant in scope, and no declaration presented at a \
          node is named so"
      | many =>
        .error s!"{data.refName} matches several declarations presented at nodes: \
          {", ".intercalate many}"
    else
      match data.docsHref? with
      | some href => .docs href
      | none =>
        .error s!"no blueprint node presents \
          {", ".intercalate (data.candidates.toList.map toString)}"

inline_extension Inline.declRef (data : DeclRefData) where
  data := toJson data
  traverse _ _ _ := pure none
  extraCss := usesAssetBundle.css
  extraJs := usesAssetBundle.js
  toHtml :=
    open Verso.Doc.Html in
    open Verso.Output.Html in
    some <| fun goI _id data contents => do
      let some data ← ExtensionDecode.decode? (α := DeclRefData) data
          (fun err => s!"Malformed data in Inline.declRef ({err}): {data}")
        | contents.mapM goI
      let st ← HtmlT.state
      let code : Verso.Output.Html := {{<code>{{data.written}}</code>}}
      match data.resolve (Resolve.canonicalDeclNames st) (Resolve.resolveCanonicalDeclHref? st) with
      | .node decl href =>
        let declName := decl.toName
        pure <| Informal.LeanCodeLink.renderResolved declName code
          (className := "bp_decl_link bp_decl_ref") (href? := some href)
          (previewTitle := s!"Lean declaration {decl}")
      | .docs href =>
        pure {{<a class="bp_decl_link bp_decl_link_docs bp_decl_ref" href={{href}}>{{code}}</a>}}
      | .error message =>
        let loc? : Option Verso.SourceLoc :=
          if data.file.isEmpty then none
          else some { file := data.file, span := .pos ⟨data.line, data.column⟩ }
        Verso.reportError s!"\{decl}`{data.written}`: {message}" loc?
        pure code
  toTeX :=
    some <| fun goI _id _data contents => contents.mapM goI

/-- Arguments of the `{decl}` role: optionally the name to resolve, when it is not the code. -/
structure DeclRefConfig where
  target : Option Ident := none

section
variable [Monad m] [MonadError m]

instance : FromArgs DeclRefConfig m where
  fromArgs :=
    DeclRefConfig.mk <$>
      ((fun _ => none) <$> .done <|>
        (some <$> .positional `name {
          description := "the declaration's name"
          signature := .Ident
          get := fun
            | .name x => pure x
            | other => throwError "Expected a declaration name, got {repr other}"
        }))

end

/--
`{decl}`Name`` renders `Name` as inline code linking to the blueprint node that presents the
declaration (see the module documentation for how the name is resolved).
-/
@[role]
def decl : RoleExpanderOf DeclRefConfig
  | cfg, contents => do
    let code ← oneCodeStr contents
    let written := code.getString.trimAscii.toString
    let name : Name ←
      match cfg.target with
      | some target => pure target.getId
      | none =>
        match LeanNameParsing.parseE written with
        | .error err =>
          throwErrorAt code m!"\{decl}: '{written}' is not a Lean name ({err}); give the name as \
            argument, as in \{decl Name}`{written}`"
        | .ok name => pure name
    let resolved ← Lean.resolveGlobalName name (enableLog := false)
    let candidates : Array Name := resolved.foldl (init := #[]) fun acc (c, fields) =>
      if fields.isEmpty && !acc.contains c then acc.push c else acc
    if let #[c] := candidates then
      addConstInfo (cfg.target.map (·.raw) |>.getD code) c
    let docsBaseUrl := verso.blueprint.externalCode.docsBaseUrl.get (← getOptions)
    let env ← getEnv
    let docsHref? :=
      match candidates with
      | #[c] => Informal.docsHref? env docsBaseUrl c
      | _ => none
    let fileMap ← getFileMap
    let lspPos := fileMap.utf8PosToLspPos (code.raw.getPos?.getD 0)
    let mut openNamespaces : Array Name :=
      ((← getOpenDecls).filterMap fun
        | .simple ns _ => some ns
        | .explicit .. => none).toArray
    let mut ns ← getCurrNamespace
    while !ns.isAnonymous do
      openNamespaces := openNamespaces.push ns
      ns := ns.getPrefix
    let enclosingDecls : Array Name ←
      match ← Environment.peek with
      | none => pure #[]
      | some cur =>
        match cur.codeHint with
        | some code => pure code.leanDecls
        | none => pure <| ((← Environment.getNode? cur.label).map (·.leanDecls)).getD #[]
    let data : DeclRefData := {
      written, candidates, docsHref?, openNamespaces, enclosingDecls
      name := if cfg.target.isSome then name.toString else ""
      file := ← getFileName
      line := lspPos.line
      column := lspPos.character
    }
    ``(Verso.Doc.Inline.other (Informal.Inline.declRef $(quote data))
        #[Verso.Doc.Inline.code $(quote written)])

end Informal

/-
Copyright (c) 2026 Lean FRO LLC. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
-/

import VersoBlueprintTests.Blueprint.Support

/-! Declaration links in rendered declaration code, and the `{decl}` role. -/

namespace BpDeclLinkFixture

def base : Nat := 0

theorem usesBase : base = 0 := rfl

def unpresented : Nat := 1

theorem usesUnpresented : unpresented = 1 := rfl

end BpDeclLinkFixture

namespace BpDeclLinkHidden.Deep

def leaf : Nat := 2

def base : Nat := 3

end BpDeclLinkHidden.Deep

namespace Verso.VersoBlueprintTests.BlueprintDeclLinks

open Verso
open Verso.Genre.Manual
open Informal
open Verso.VersoBlueprintTests.Blueprint.Support
open BpDeclLinkFixture

set_option doc.verso true

def manualImpls : ExtensionImpls := extension_impls%

/-- Render like the shared support helper, collecting the build errors. -/
def renderWithErrors (doc : Doc.VersoDoc Genre.Manual) :
    IO (String × Array String × TraverseState) := do
  let errors ← IO.mkRef (#[] : Array String)
  let logger : Logger IO := {
    log := fun severity text _loc => do
      if severity matches .error then errors.modify (·.push text)
    errors := pure #[]
    warnings := pure #[]
  }
  let (blocks, st) ← traverseManualDocBlocksAndState manualImpls doc
  let htmlState :
      StateT (Code.Hover.State Output.Html)
        (ReaderT Multi.AllRemotes (ReaderT ExtensionImpls (BuildLogT IO)))
        Output.Html :=
    Verso.Genre.Manual.toHtml { headerLevel := 1 } {} st {} {} {} (Doc.Block.concat blocks)
  let (html, _) ← ((htmlState.run {}).run {}) |>.run manualImpls |>.run logger
  pure (html.asString, ← errors.get, st)

-- Marker resolution.

/-- info: true -/
#guard_msgs in
#eval
  let html := "<pre><!--bp-decl:A.b|-->x<!--/bp-decl--> <!--bp-decl:C%2Dd|https://docs/C.html#C%2Dd-->y<!--/bp-decl--> <!--bp-decl:E|-->z<!--/bp-decl--></pre>"
  let out := Informal.rewriteDeclLinks html fun
    | "A.b" => some "page#a"
    | _ => none
  out == "<pre><a class=\"bp_decl_link\" href=\"page#a\">x</a> <a class=\"bp_decl_link bp_decl_link_docs\" href=\"https://docs/C.html#C-d\">y</a> z</pre>"

-- Resolution of role references.

/-- info: true -/
#guard_msgs in
#eval
  let nodeDecls := #["A.B.leaf", "A.C.leaf", "A.B.trunk"]
  let href : String → Option String := fun d => if nodeDecls.contains d then some s!"#{d}" else none
  let r (data : DeclRefData) := data.resolve nodeDecls href
  r { written := "trunk", candidates := #[`A.B.trunk] } == .node "A.B.trunk" "#A.B.trunk" &&
  -- Of several constants in scope, the one a node presents.
  r { written := "trunk", candidates := #[`trunk, `A.B.trunk] } == .node "A.B.trunk" "#A.B.trunk" &&
  -- Suffix matching only when the name denotes no constant.
  r { written := "B.trunk" } == .node "A.B.trunk" "#A.B.trunk" &&
  (r { written := "leaf" } matches .error _) &&
  -- Several suffix matches: the one inside an open namespace.
  r { written := "leaf", openNamespaces := #[`A.C] } == .node "A.C.leaf" "#A.C.leaf" &&
  (r { written := "leaf", openNamespaces := #[`A] } matches .error _) &&
  -- Inside a node, its own declarations come first.
  r { written := "trunk", candidates := #[`A.B.trunk], enclosingDecls := #[`A.C.leaf] } ==
    .node "A.B.trunk" "#A.B.trunk" &&
  r { written := "leaf", candidates := #[`A.B.leaf], enclosingDecls := #[`A.C.leaf] } ==
    .node "A.C.leaf" "#A.C.leaf" &&
  (r { written := "C.leaf", candidates := #[`Other.C.leaf] } matches .error _) &&
  r { written := "C.leaf", candidates := #[`Other.C.leaf], docsHref? := some "https://d" } == .docs "https://d" &&
  (r { written := "nope" } matches .error _)

-- Rendered documents.

#docs (Genre.Manual) declLinksDoc "Declaration links" :=
:::::::
:::theorem "thm:uses_base" (lean := "BpDeclLinkFixture.usesBase, BpDeclLinkFixture.base")
A theorem node that also presents the definition.
:::

:::definition "def:base" (lean := "BpDeclLinkFixture.base")
The definition node.
:::

:::theorem "thm:uses_unpresented" (lean := "BpDeclLinkFixture.usesUnpresented")
Mentions a constant no node presents.
:::

:::definition "def:leaf" (lean := "BpDeclLinkHidden.Deep.leaf")
A declaration in a namespace that is not open.
:::

:::definition "def:deep_base" (lean := "BpDeclLinkHidden.Deep.base")
In this node {decl}`base` is the node's own declaration.
:::

Prose: {decl}`base`, {decl}`BpDeclLinkFixture.usesBase`, {decl}`Deep.leaf`, {decl}`Nat.add` and
{decl usesBase}`base = 0`.
:::::::

#docs (Genre.Manual) declLinksErrorDoc "Declaration link errors" :=
:::::::
:::theorem "thm:uses_unpresented_2" (lean := "BpDeclLinkFixture.usesUnpresented")
Statement.
:::

Prose: {decl}`unpresented` and {decl}`noSuchName`.
:::::::

/-- The page link of the rendering of a declaration at a node. -/
private def rowHref (st : TraverseState) (label decl : Lean.Name) : String :=
  s!"href=\"{(Informal.Resolve.resolveRenderedExternalDeclHref? st label decl).getD "?"}\""

/-- info: true -/
#guard_msgs in
#eval
  show IO Bool from do
    let (out, errors, st) ← renderWithErrors declLinksDoc
    let defBase := rowHref st (.mkSimple "def:base") `BpDeclLinkFixture.base
    let thmBase := rowHref st (.mkSimple "thm:uses_base") `BpDeclLinkFixture.base
    pure (
      errors.isEmpty && defBase != thmBase &&
      -- The signature of usesBase links base to the definition node, not to the theorem node
      -- that presents it first.
      hasSubstr out s!"<a class=\"bp_decl_link\" {defBase}><span class=\"const token\" data-binding=\"const-BpDeclLinkFixture.base\"" &&
      !hasSubstr out s!"{thmBase}><span" &&
      -- Core constants link to the API documentation.
      hasSubstr out "<a class=\"bp_decl_link bp_decl_link_docs\" href=\"https://leanprover-community.github.io/mathlib4_docs/Init/Prelude.html#Eq\"><span class=\"const token\" data-binding=\"const-Eq\"" &&
      -- A constant without node keeps its hover and gets no link; no marker survives.
      hasSubstr out "</span><span class=\"const token\" data-binding=\"const-BpDeclLinkFixture.unpresented\" data-verso-hover=" &&
      !hasSubstr out "bp-decl:" && !hasSubstr out "/bp-decl" &&
      -- The role: relative, qualified and suffix names, and a documentation link.
      hasSubstr out s!"<a class=\"bp_decl_link bp_decl_ref\" {defBase}><code>base</code></a>" &&
      hasSubstr out s!"<a class=\"bp_decl_link bp_decl_ref\" {rowHref st (.mkSimple "thm:uses_base") `BpDeclLinkFixture.usesBase}><code>BpDeclLinkFixture.usesBase</code></a>" &&
      hasSubstr out s!"<a class=\"bp_decl_link bp_decl_ref\" {rowHref st (.mkSimple "def:leaf") `BpDeclLinkHidden.Deep.leaf}><code>Deep.leaf</code></a>" &&
      hasSubstr out "<a class=\"bp_decl_link bp_decl_link_docs bp_decl_ref\" href=\"https://leanprover-community.github.io/mathlib4_docs/Init/Prelude.html#Nat.add\"><code>Nat.add</code></a>" &&
      -- Inside a node, the node's declaration.
      hasSubstr out s!"<a class=\"bp_decl_link bp_decl_ref\" {rowHref st (.mkSimple "def:deep_base") `BpDeclLinkHidden.Deep.base}><code>base</code></a>" &&
      -- An explicit name, displayed as the code.
      hasSubstr out s!"<a class=\"bp_decl_link bp_decl_ref\" {rowHref st (.mkSimple "thm:uses_base") `BpDeclLinkFixture.usesBase}><code>base = 0</code></a>"
    )

/--
info: {decl}`unpresented`: no blueprint node presents BpDeclLinkFixture.unpresented
{decl}`noSuchName`: noSuchName is not a constant in scope, and no declaration presented at a node is named so
-/
#guard_msgs in
#eval
  show IO Unit from do
    let (_, errors, _) ← renderWithErrors declLinksErrorDoc
    for e in errors do IO.println e

end Verso.VersoBlueprintTests.BlueprintDeclLinks

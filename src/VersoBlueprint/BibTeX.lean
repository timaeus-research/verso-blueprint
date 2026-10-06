/-
Copyright (c) 2026 Timaeus. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
-/

import Lean
import Verso.Instances
import BibtexQuery.Parser
import BibtexQuery.Format

/-!
# A bibliography read from a BibTeX file

`blueprint_bibliography_file "path"` reads a BibTeX file (relative to the directory of the file
holding the command) and registers each entry under its key, formatted by BibtexQuery as doc-gen4
formats the references page of an API documentation: an alpha-style tag (`Kol07`; `BM97`;
`TSPA` for a corporate author) and the entry's HTML. The registry is a persistent environment
extension, so a module that cites with the `{cite KEY}` role (`VersoBlueprint.Cite`) or whose
docstring annotation items say `[KEY, locator]` (`VersoBlueprint.SourceAnnotations`) imports the
module that runs the command; an unknown key is an elaboration error. `blueprint_bibliography`
(`VersoBlueprint.Commands.Bibliography`) lists the entries.

Lake does not see that a module reads a file: declare the file as an `input_file` and a `needs`
of the library holding the registering module, so that a change to the file rebuilds the registry
and the modules that import it.

BibtexQuery reads the usual subset of BibTeX: `@type{key, field = {value}, ...}`, values in
braces or bare numbers, keys of ASCII letters, digits, `:`, `-` and `_`; no `@string`, no `#`
concatenation. Accents may be written as TeX commands or as Unicode. The parser stops silently at
the first malformed entry; `process` reports that as an error instead.
-/

open Lean

namespace Informal.BibTeX

/-- One formatted entry of a BibTeX file. -/
structure BibItem where
  /-- The key of the entry, as cited: `Kol07`. -/
  key : String
  /-- The alpha-style tag BibtexQuery generates from the authors and the year, without brackets:
  `Kol07`, `BM97`, `Kol07a` when two entries share a tag. -/
  tag : String
  /-- The entry formatted as HTML (escaped). -/
  html : String
  /-- The entry as plain text. -/
  plaintext : String
  /-- The position of the entry in the formatted bibliography (sorted by author, year and title). -/
  order : Nat
deriving Inhabited, Repr, BEq, FromJson, ToJson, Quote

section Serialisation

open BibtexQuery.Xml

private def escapeHtml (s : String) : String :=
  s.replace "&" "&amp;" |>.replace "<" "&lt;" |>.replace ">" "&gt;" |>.replace "\"" "&quot;"
    |>.replace "'" "&#39;"

mutual

/-- An XML element as an HTML string, with text and attribute values escaped. -/
partial def elementToHtml : Element → String
  | .Element n a c =>
    let attrs := a.foldl (fun s n v => s ++ s!" {n}=\"{escapeHtml v}\"") ""
    s!"<{n}{attrs}>{c.map contentToHtml |>.foldl (· ++ ·) ""}</{n}>"

/-- XML content as an HTML string, with text and attribute values escaped. -/
partial def contentToHtml : Content → String
  | .Element e => elementToHtml e
  | .Comment c => s!"<!--{c}-->"
  | .Character c => escapeHtml c

end

mutual

/-- The text of an XML element. -/
partial def elementToPlain : Element → String
  | .Element _ _ c => c.map contentToPlain |>.foldl (· ++ ·) ""

/-- The text of XML content. -/
partial def contentToPlain : Content → String
  | .Element e => elementToPlain e
  | .Comment _ => ""
  | .Character c => c

end

end Serialisation

/-- The tag of a processed entry without the brackets BibtexQuery puts around it. -/
private def tagBody (tag : String) : String :=
  ((tag.dropPrefix "[").dropSuffix "]").copy

/--
The entries of BibTeX text, formatted, sorted and with their tags made distinct. An error names
the offset of the first malformed entry; the parser otherwise stops there silently.
-/
def process (text : String) : Except String (Array BibItem) := do
  match BibtexQuery.Parser.bibtexFile ⟨text, text.startPos⟩ with
  | .error it err =>
    throw s!"malformed BibTeX at offset {it.2.offset.byteIdx}: {err}"
  | .success it entries =>
    let rest := it.1.extract it.2 it.1.endPos
    if rest.contains '@' then
      let shown := (rest.dropWhile (· != '@')).take 60
      throw s!"malformed BibTeX entry after offset {it.2.offset.byteIdx}: {shown}…"
    if entries.isEmpty then
      throw "no BibTeX entries"
    let processed ← entries.toArray.filterMapM BibtexQuery.ProcessedEntry.ofEntry
    let processed := processed |> BibtexQuery.sortEntry |> BibtexQuery.deduplicateTag
    return processed.mapIdx fun i e =>
      let html := BibtexQuery.Formatter.format e
      {
        key := e.name
        tag := tagBody e.tag
        html := html.map contentToHtml |>.toList |> String.join
        plaintext := html.map contentToPlain |>.toList |> String.join
        order := i
      }

/-- The bibliography registry: the entries registered by `blueprint_bibliography_file` and
`blueprint_bibliography_bibtex`, by key. -/
initialize bibtexExt : PersistentEnvExtension BibItem BibItem (Std.HashMap String BibItem) ←
  registerPersistentEnvExtension {
    mkInitial := pure {}
    addImportedFn := fun es =>
      pure <| es.foldl (init := ({} : Std.HashMap String BibItem)) fun acc entries =>
        entries.foldl (fun acc b => acc.insert b.key b) acc
    addEntryFn := fun st b => st.insert b.key b
    exportEntriesFn := fun st =>
      st.toArray.map (·.2) |>.qsort (fun a b => a.order < b.order || (a.order == b.order && a.key < b.key))
  }

/-- The registered entry with key `key`. -/
def lookup? (env : Environment) (key : String) : Option BibItem :=
  (bibtexExt.getState env)[key]?

/-- Every registered entry, in bibliography order. -/
def allItems (env : Environment) : Array BibItem :=
  (bibtexExt.getState env).toArray.map (·.2)
    |>.qsort (fun a b => a.order < b.order || (a.order == b.order && a.key < b.key))

open Elab Command in
/-- Register the entries of the BibTeX `text` (from `source`, named in errors), reporting at `ref`. -/
def registerBibtex (ref : Syntax) (source : String) (text : String) : CommandElabM Unit := do
  let items ← match process text with
    | .ok items => pure items
    | .error err => throwErrorAt ref "{source}: {err}"
  for item in items do
    let env ← getEnv
    if (lookup? env item.key).isSome then
      throwErrorAt ref "{source}: the key `{item.key}` is already registered"
    for other in allItems env do
      if other.tag == item.tag then
        logWarningAt ref m!"{source}: `{item.key}` has the tag [{item.tag}] of the registered \
          entry `{other.key}`"
      if other.key != item.key && other.key.toLower == item.key.toLower then
        logWarningAt ref m!"{source}: `{item.key}` and the registered entry `{other.key}` differ \
          only in case; their citations link to the same anchor"
    modifyEnv (bibtexExt.addEntry · item)

/--
`blueprint_bibliography_file "path"` registers the entries of the BibTeX file at `path`, relative
to the directory of the current file, for `{cite KEY}`, the `[KEY, locator]` citations of
docstring annotation items, and `blueprint_bibliography`. See the module documentation for the
dialect read and for making Lake rebuild on a change to the file.
-/
syntax (name := bibliographyFile) "blueprint_bibliography_file " str : command

/--
`blueprint_bibliography_bibtex "text"` registers the entries of the BibTeX `text` itself, as
`blueprint_bibliography_file` registers those of a file.
-/
syntax (name := bibliographyBibtex) "blueprint_bibliography_bibtex " str : command

open Elab Command in
@[command_elab bibliographyFile, inherit_doc bibliographyFile]
def elabBibliographyFile : CommandElab
  | `(blueprint_bibliography_file $path) => do
    let some dir := (System.FilePath.mk (← getFileName)).parent
      | throwError "cannot compute the directory of the current file"
    let name := path.getString
    let text ← match ← (IO.FS.readFile (dir / name)).toBaseIO with
      | .ok text => pure text
      | .error e => throwErrorAt path "cannot read the bibliography {name}: {toString e}"
    registerBibtex path name text
  | _ => throwUnsupportedSyntax

open Elab Command in
@[command_elab bibliographyBibtex, inherit_doc bibliographyBibtex]
def elabBibliographyBibtex : CommandElab
  | `(blueprint_bibliography_bibtex $text) => registerBibtex text "inline BibTeX" text.getString
  | _ => throwUnsupportedSyntax

/-! ### Bracketed citations in Markdown

A docstring cites as `[KEY]` or `[KEY, locator]`; these read such a label. -/

/-- The key of a bracketed citation `[KEY]` or `[KEY, locator]`: the text before the first comma,
trimmed. -/
def citationKey (label : String) : String :=
  (label.splitOn ",").head!.trimAscii.copy

/-- `s` trimmed, with each run of white space (a line break and the indentation after it) one
space. -/
def normalizeLocator (s : String) : String :=
  " ".intercalate (s.splitToList Char.isWhitespace |>.filter (!·.isEmpty))

/-- The locator of a bracketed citation `[KEY, locator]` of `key`, if `label` is one: `"Definition
29"` for `"Kol07, Definition 29"`, `none` for `"Kol07"` and for other keys. White space is
normalized (`normalizeLocator`). -/
def citationLocator? (key label : String) : Option String :=
  match label.splitOn "," with
  | k :: _ :: _ =>
    if k.trimAscii == key then
      let locator := normalizeLocator (label.drop (k.length + 1)).copy
      if locator.isEmpty then none else some locator
    else
      none
  | _ => none

/-- The bracketed labels of `s` whose key is registered, each with its entry: `[Kol07, Definition
29]` gives `("Kol07, Definition 29", ⟨Kol07⟩)`. A label with a line break inside counts, with the
break as written. -/
partial def findCitations (env : Environment) (s : String) : Array (String × BibItem) :=
  go s.startPos #[]
where
  go (i : s.Pos) (acc : Array (String × BibItem)) : Array (String × BibItem) :=
    let lps := i.find '['
    if hs : lps ≠ s.endPos then
      let lpe := lps.find ']'
      if lpe ≠ s.endPos then
        let label := s.extract (lps.next hs) lpe
        match lookup? env (citationKey label) with
        | some item =>
          if acc.any (·.1 == label) then go lpe acc else go lpe (acc.push (label, item))
        | none => go lpe acc
      else
        acc
    else
      acc

end Informal.BibTeX

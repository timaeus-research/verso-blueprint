/-
Copyright (c) 2026 Timaeus. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
-/

import Lean

/-!
# The review ledger

Whether a human has checked an annotation taken from a docstring is recorded outside the docstring,
in a JSON file: an array of entries

```
{"decl": "Full.Declaration.name", "kind": "Translation", "hash": "0123456789abcdef",
 "reviewer": "BS", "date": "2026-10-02"}
```

where `kind` is one of `Translation`, `Interpretation`, `Correction`, `Formalisation note` and
`hash` is `Informal.SourceRelation.itemHash` of the item's text. An item is

* *reviewed* when an entry with its declaration, kind and hash exists (the badge names the reviewer
  and the date of the latest such entry);
* *changed since review* when entries with its declaration and kind exist but none with its hash;
* *unreviewed* otherwise, and always when the ledger file does not exist.

The ledger is read when the HTML is generated (not when the Lean files are elaborated), so editing
it needs no rebuild of the document's Lean modules; each file is read once per process.

Review badges can be hidden for a whole build: `lake exe vbp build --hide-review`, or
`--hide-review` given to the generator directly, or the environment variable
`VERSO_BLUEPRINT_HIDE_REVIEW=1`.
-/

namespace Informal.ReviewLedger

open Lean

/-- One review: a person checked the item of `kind` with this `hash` in `decl`'s docstring. -/
structure Entry where
  decl : String
  kind : String
  hash : String
  reviewer : String
  date : String
deriving Repr, Inhabited, BEq, FromJson, ToJson

/-- The kinds a ledger entry may name. -/
def kinds : List String := ["Translation", "Interpretation", "Correction", "Formalisation note"]

private def isLowerHex (c : Char) : Bool := c.isDigit || ('a' ≤ c && c ≤ 'f')

/-- What is wrong with an entry, if anything. -/
def Entry.problem? (e : Entry) : Option String :=
  let date := e.date.toList
  if e.decl.isEmpty then some "empty decl"
  else if !kinds.contains e.kind then
    some s!"kind {e.kind.quote} is not one of {", ".intercalate kinds}"
  else if !(e.hash.length == 16 && e.hash.toList.all isLowerHex) then
    some s!"hash {e.hash.quote} is not 16 lowercase hexadecimal digits"
  else if e.reviewer.isEmpty then some "empty reviewer"
  else if !(date.length == 10 && date[4]? == some '-' && date[7]? == some '-' &&
      (date.take 4 ++ (date.drop 5).take 2 ++ date.drop 8).all Char.isDigit) then
    some s!"date {e.date.quote} is not YYYY-MM-DD"
  else none

/-- The review state of one item. -/
inductive Status where
  | unreviewed
  | changedSinceReview
  | reviewed (reviewer date : String)
deriving Repr, Inhabited, BEq

/-- Parse a ledger's text: the valid entries, and a message for each problem. -/
def parseLedger (text : String) : Array Entry × Array String := Id.run do
  match Json.parse text with
  | .error err => return (#[], #[s!"not JSON: {err}"])
  | .ok json =>
    let .ok arr := json.getArr?
      | return (#[], #["expected a JSON array of entries"])
    let mut entries := #[]
    let mut problems := #[]
    for h : i in [0:arr.size] do
      match fromJson? (α := Entry) arr[i] with
      | .error err => problems := problems.push s!"entry {i}: {err}"
      | .ok e =>
        match e.problem? with
        | some p => problems := problems.push s!"entry {i}: {p}"
        | none => entries := entries.push e
    return (entries, problems)

/-- The state of the item of `kind` with `hash` in `decl`'s docstring, according to `entries`. -/
def status (entries : Array Entry) (decl kind hash : String) : Status :=
  let sameKind := entries.filter fun e => e.decl == decl && e.kind == kind
  let matching := sameKind.filter (·.hash == hash)
  match matching.foldl (init := none) (fun best e =>
      match best with
      | some (b : Entry) => if e.date > b.date then some e else some b
      | none => some e) with
  | some e => .reviewed e.reviewer e.date
  | none => if sameKind.isEmpty then .unreviewed else .changedSinceReview

/-! ## Per-process state -/

private structure Loaded where
  entries : Array Entry
  problems : Array String

initialize loadedRef : IO.Ref (Std.HashMap String Loaded) ← IO.mkRef {}

initialize hideReviewRef : IO.Ref Bool ← IO.mkRef false

/-- The command-line flag of the generator (and of `lake exe vbp build`) that hides review badges. -/
def hideReviewFlag : String := "--hide-review"

/-- The environment variable that hides review badges when set to a value other than `0` or empty. -/
def hideReviewEnvVar : String := "VERSO_BLUEPRINT_HIDE_REVIEW"

/-- Hide (or show) every review badge in this process. -/
def setHideReview (hide : Bool) : IO Unit :=
  hideReviewRef.set hide

/-- Whether review badges are hidden: `setHideReview true` was called (the generator does so for
`--hide-review`), or `VERSO_BLUEPRINT_HIDE_REVIEW` is set to a value other than `0` or empty. -/
def reviewHidden : IO Bool := do
  if ← hideReviewRef.get then return true
  match ← IO.getEnv hideReviewEnvVar with
  | some v => return !(v.isEmpty || v == "0")
  | none => return false

/-- Remove `--hide-review` from generator arguments, recording it. -/
def takeHideReviewFlag (args : List String) : IO (List String) := do
  if args.contains hideReviewFlag then
    setHideReview true
    return args.filter (· != hideReviewFlag)
  return args

/-- Forget the ledgers read so far (for tests and long-lived tools). -/
def clearCache : IO Unit :=
  loadedRef.set {}

/--
The entries of the ledger at `path` (relative paths are relative to the current directory, which is
the package root under `lake exe vbp build`), read once per process, with the problems found on the
first read. A missing file has no entries and no problems.
-/
def load (path : String) : IO (Array Entry × Array String × Bool) := do
  if let some l := (← loadedRef.get)[path]? then
    return (l.entries, l.problems, false)
  let fp : System.FilePath := path
  let (entries, problems) ←
    if ← fp.pathExists then
      try
        pure (parseLedger (← IO.FS.readFile fp))
      catch e =>
        pure (#[], #[s!"cannot be read: {e}"])
    else
      pure (#[], #[])
  loadedRef.modify (·.insert path { entries, problems })
  return (entries, problems, true)

end Informal.ReviewLedger

/-
Copyright (c) 2026 Timaeus. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
-/

import Lean

/-!
# The "Relation to the source." section of a docstring

A declaration's docstring may say how its statement relates to the source it formalises, in a
section of labelled bullets:

```
Relation to the source.
* **Translation.** `S.weakTransformSeq J i` is Hironaka's $J_i$, and `S.boundarySeq E₀ i` his $E_i$.
* **Interpretation.** Hironaka's "non-singular" is read as smooth over `k`; ...
* **Correction.** ...
* **Formalisation note.** ...
```

This module parses that section (no Verso, no IO): the blueprint renders each item as an annotation
box at the node that embeds the declaration and removes the section from the plain docstring it
displays, and the review ledger identifies an item by `itemHash`.

Parsing rules:

* The heading is the first line whose text, without leading and trailing whitespace, is exactly
  `Relation to the source.`; its indentation is the section's base indentation.
* After the heading (blank lines allowed) comes a list of bullets. A bullet is a line indented at
  most three columns more than the heading whose text starts with `* `, `- ` or `+ `.
* An item continues on the following lines that are indented more than its bullet; blank lines
  inside an item separate paragraphs.
* The section ends before the first non-blank line that is neither a bullet nor a continuation
  (and before the blank lines preceding it), or at the end of the docstring.
* Each item begins with exactly one of the bold labels `**Translation.**`,
  `**Interpretation.**`, `**Correction.**`, `**Formalisation note.**` (the period inside the bold).
  The item's text is everything after the label, continuation lines included; it is Markdown
  (inline code, emphasis, inline LaTeX `$...$`).
* A bullet without a bold label, or with a bold label that is not one of the four, is a problem:
  it is reported and stays in the plain docstring display, under the heading.
-/

namespace Informal.SourceRelation

/-- The heading line of the section. -/
def heading : String := "Relation to the source."

/-- The four labels of an item. -/
inductive Label where
  | translation
  | interpretation
  | correction
  | formalisationNote
deriving BEq, Repr, Inhabited, DecidableEq

/-- The label as written between the bold markers, without its period; also the ledger's `kind`. -/
def Label.text : Label → String
  | .translation => "Translation"
  | .interpretation => "Interpretation"
  | .correction => "Correction"
  | .formalisationNote => "Formalisation note"

/-- The key of the blueprint annotation kind that renders this label (`Informal.Editorial.Kind.key`). -/
def Label.kindKey : Label → String
  | .translation => "translation"
  | .interpretation => "interpretation"
  | .correction => "correction"
  | .formalisationNote => "meta"

def Label.all : List Label := [.translation, .interpretation, .correction, .formalisationNote]

def Label.ofText? (text : String) : Option Label :=
  Label.all.find? (·.text == text)

/-- One labelled item of the section. -/
structure Item where
  label : Label
  /-- The item's text after the label, as Markdown: continuation lines without their indentation,
  paragraphs separated by an empty line. -/
  markdown : String
deriving Repr, Inhabited, BEq

/-- A bullet of the section that is not a labelled item. -/
inductive Problem where
  /-- The bullet does not start with a bold label. -/
  | unlabelled (bullet : String)
  /-- The bullet starts with a bold label that is not one of the four (the text between the bold
  markers is given). -/
  | unknownLabel (label : String) (bullet : String)
  /-- The heading is not followed by a list of bullets. -/
  | noItems
deriving Repr, Inhabited, BEq

def Problem.message : Problem → String
  | .unlabelled bullet =>
    s!"a bullet of the \"{heading}\" section has no label (expected **Translation.**, " ++
      s!"**Interpretation.**, **Correction.** or **Formalisation note.**): {bullet}"
  | .unknownLabel label bullet =>
    s!"unknown label **{label}** in the \"{heading}\" section (expected **Translation.**, " ++
      s!"**Interpretation.**, **Correction.** or **Formalisation note.**): {bullet}"
  | .noItems =>
    s!"the \"{heading}\" heading is not followed by a list of labelled bullets"

/-- The result of parsing one docstring. -/
structure Parsed where
  /-- The labelled items, in docstring order. -/
  items : Array Item := #[]
  /-- The bullets that could not be read as labelled items, and other problems. -/
  problems : Array Problem := #[]
  /-- The docstring without the section, for the plain display. Bullets with problems stay, under
  the heading. Equal to the input when there is no section. -/
  remainder : String
deriving Repr, Inhabited

/-! ## Whitespace and the item hash -/

/-- The whitespace characters of `normalizeWhitespace`: space, tab, line feed, carriage return. -/
def isHashWhitespace (c : Char) : Bool :=
  c == ' ' || c == '\t' || c == '\n' || c == '\r'

/--
`s` with every run of whitespace (space U+0020, tab U+0009, line feed U+000A, carriage return
U+000D; no other character counts) replaced by one space, and no whitespace at either end.
In Python: `re.sub(r"[ \t\n\r]+", " ", s).strip(" ")`.
-/
def normalizeWhitespace (s : String) : String := Id.run do
  let mut out : List Char := []
  let mut pendingSpace := false
  for c in s.toList do
    if isHashWhitespace c then
      pendingSpace := !out.isEmpty
    else
      if pendingSpace then out := ' ' :: out
      pendingSpace := false
      out := c :: out
  return String.ofList out.reverse

/-- The 64-bit FNV-1a offset basis. -/
def fnvOffsetBasis : UInt64 := 0xcbf29ce484222325

/-- The 64-bit FNV prime. -/
def fnvPrime : UInt64 := 0x100000001b3

/-- 64-bit FNV-1a of a byte string: for each byte, xor it into the state, then multiply by the
prime modulo 2^64. -/
def fnv1a64 (bytes : ByteArray) : UInt64 :=
  bytes.foldl (init := fnvOffsetBasis) fun h b => (h ^^^ b.toUInt64) * fnvPrime

/-- `n` as exactly 16 lowercase hexadecimal digits. -/
def hex16 (n : UInt64) : String :=
  let digits := Nat.toDigits 16 n.toNat
  String.ofList (List.replicate (16 - digits.length) '0' ++ digits)

/--
The identity of an item's text in the review ledger: 64-bit FNV-1a over the UTF-8 bytes of the
text after the label with its whitespace normalized (`normalizeWhitespace`), written as 16
lowercase hexadecimal digits. Rewrapping or reindenting an item keeps its hash; any other edit
changes it.

In Python:
```
def item_hash(text: str) -> str:
    h = 0xcbf29ce484222325
    for b in re.sub(r"[ \t\n\r]+", " ", text).strip(" ").encode("utf-8"):
        h = ((h ^ b) * 0x100000001b3) & 0xFFFFFFFFFFFFFFFF
    return f"{h:016x}"
```
-/
def itemHash (text : String) : String :=
  hex16 (fnv1a64 (normalizeWhitespace text).toUTF8)

def Item.hash (item : Item) : String := itemHash item.markdown

/-! ## Parsing -/

private def isIndentChar (c : Char) : Bool := c == ' ' || c == '\t'

private def indentOf (line : String) : Nat :=
  (line.toList.takeWhile isIndentChar).length

private def dropIndent (line : String) : List Char :=
  line.toList.dropWhile isIndentChar

private def isBlank (line : String) : Bool :=
  line.toList.all isHashWhitespace

private def trimLine (line : String) : String :=
  String.ofList ((dropIndent line).reverse.dropWhile isHashWhitespace).reverse

/-- The text of a bullet line after its marker, when the line is a bullet relative to `base`. -/
private def bulletContent? (base : Nat) (line : String) : Option (List Char) :=
  if indentOf line > base + 3 then none
  else
    match dropIndent line with
    | m :: c :: rest =>
      if (m == '*' || m == '-' || m == '+') && isIndentChar c then
        some (rest.dropWhile isIndentChar)
      else none
    | _ => none

/-- Split `**label**rest` into the bold text and the rest; `none` without a leading bold span. -/
private def splitBold? (content : List Char) : Option (String × List Char) :=
  match content with
  | '*' :: '*' :: rest =>
    let rec go (acc : List Char) : List Char → Option (String × List Char)
      | '*' :: '*' :: after => some (String.ofList acc.reverse, after)
      | c :: more => go (c :: acc) more
      | [] => none
    go [] rest
  | _ => none

/-- One bullet of the section, with the line range it occupies. -/
private structure Bullet where
  firstLine : Nat
  /-- One past the last line of the bullet (its trailing blank lines excluded). -/
  endLine : Nat
  indent : Nat
  content : List Char
  continuation : Array String := #[]

private inductive ReadBullet where
  | item (item : Item)
  | problem (problem : Problem)

private def readBullet (b : Bullet) : ReadBullet :=
  let shown := trimLine (String.ofList b.content)
  match splitBold? b.content with
  | none => .problem (.unlabelled shown)
  | some (bold, after) =>
    let label? :=
      if bold.endsWith "." then Label.ofText? (bold.dropEnd 1).toString else none
    match label? with
    | none => .problem (.unknownLabel bold shown)
    | some label =>
      let first := trimLine (String.ofList after)
      let rest := b.continuation.toList.map trimLine
      -- drop the trailing blank lines kept while scanning
      let lines := (first :: rest).reverse.dropWhile String.isEmpty |>.reverse
      .item { label, markdown := "\n".intercalate lines }

/-- Parse a docstring's "Relation to the source." section. -/
def parse (docs : String) : Parsed := Id.run do
  let lines := (docs.splitOn "\n").toArray
  let some h := lines.findIdx? (fun line => trimLine line == heading)
    | return { remainder := docs }
  let base := indentOf lines[h]!
  let mut bullets : Array Bullet := #[]
  let mut cur? : Option Bullet := none
  let mut sectionEnd := h + 1
  let mut i := h + 1
  let mut stop := false
  while i < lines.size && !stop do
    let line := lines[i]!
    if isBlank line then
      if let some cur := cur? then
        cur? := some { cur with continuation := cur.continuation.push "" }
      i := i + 1
    else if let some content := bulletContent? base line then
      if let some cur := cur? then bullets := bullets.push cur
      cur? := some { firstLine := i, endLine := i + 1, indent := indentOf line, content }
      sectionEnd := i + 1
      i := i + 1
    else
      match cur? with
      | some cur =>
        if indentOf line > cur.indent then
          cur? := some { cur with
            endLine := i + 1, continuation := cur.continuation.push line }
          sectionEnd := i + 1
          i := i + 1
        else
          stop := true
      | none => stop := true
  if let some cur := cur? then bullets := bullets.push cur
  if bullets.isEmpty then
    return { problems := #[.noItems], remainder := docs }
  let mut items : Array Item := #[]
  let mut problems : Array Problem := #[]
  let mut keptLines : Array String := #[]
  for b in bullets do
    match readBullet b with
    | .item item => items := items.push item
    | .problem p =>
      problems := problems.push p
      keptLines := keptLines ++ (lines.extract b.firstLine b.endLine)
  let before := (lines.extract 0 h).toList.reverse.dropWhile isBlank |>.reverse
  let after := (lines.extract sectionEnd lines.size).toList.dropWhile isBlank
  let middle : List String :=
    if keptLines.isEmpty then [] else lines[h]! :: keptLines.toList
  let chunks := [before, middle, after].filter (!·.isEmpty)
  let remainder := "\n\n".intercalate (chunks.map ("\n".intercalate ·))
  return { items, problems, remainder }

/-- The docstring without its "Relation to the source." section (see `parse`). -/
def stripSection (docs : String) : String :=
  (parse docs).remainder

end Informal.SourceRelation

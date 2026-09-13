# Contextual occurrence evidence

Enable `set_option verso.blueprint.collectOccurrences true` before a blueprint
document to capture evidence from its already elaborated native Lean blocks.
The option defaults to false. Collection runs only in batch builds, not the
language server. This is an authoring/audit API, not a glossary renderer.

`Informal.OccurrenceInventory.blocks env` returns the captured blocks, including
those imported from compiled documents. `exportJson env` returns a versioned
JSON object. For example, a separate module importing the built paper can run:

```lean
open Lean Elab Command
run_cmd do
  let data := Informal.OccurrenceInventory.exportJson (← getEnv)
  liftIO <| IO.FS.writeFile "occurrences.json" data.pretty
```

Each block records its filename, optional Lean-block label, visibility and
capture status. Each occurrence includes native byte positions, syntax kind
and reprinted syntax, its contextual application/type and constant references,
and a bounded display of its local context. Ranges refer to the native parser
file map; `source` is syntax reprinting, not a promise of byte-identical source
extraction. Macro/synthetic records remain explicitly distinguishable.

Instance records come from the actual instance-implicit argument slots of the
elaborated application. They include the argument expression, instantiated
type and recognized class, not a new typeclass-synthesis query. `isLocal` means
the argument is directly a local variable; `usesLocals` also includes composite
instances built from local parameters. A generic multiplication can select such
a composite `HMul` instance using a local `Mul` parameter. Neither flag says
the instance was explicitly written in the source.

## Coverage and limits

- Captures blueprint-owned `lean` and hidden `internal` blocks through the
  existing sequential command elaborator, preserving their actual scopes.
  Hidden setup is marked, not conflated with visible mathematical code.
- Captures saved term/binder information and macro expansion syntax. It is
  **not** a claim that every notation token has exactly one semantic meaning or
  that every source syntax node has saved term information. Nested records may
  overlap; consumers should not deduplicate solely by glyph or constant name.
- Does not inspect imported bodies, scan the source against a final environment,
  inventory upstream inline Lean roles, or classify mathematical relevance.
- Does not retain full environments or portable elaboratable expressions.
  Applications/types are contextual displays, not strings guaranteed to elaborate
  again in an unrelated scope. No automatic semantic explanation is supplied.
- `verso.blueprint.maxOccurrences` limits inspected info-tree nodes per block
  (default 2000); exhausted traversal reports `bounded`. Large term expressions
  are skipped with `expression-budget` (2000 expression nodes). Local-context
  displays retain at most 32 entries and report `localsTruncated`. These are
  practical traversal/display guards, not a strict wall-clock or byte-size cap.
- Missing context, partial elaboration, unresolved metavariables and inspection
  failures are explicit statuses. `captured` means traversal completed within
  this API's boundary, **not** complete mathematical/notation coverage. Errors
  in a document still fail its normal build; this API does not certify invalid
  code or suppress its diagnostics.

The generic tests use the same glyph and operand type in two scopes resolving
to `Nat.add` and `Nat.mul`, concrete and local multiplication instances, hidden
code, partial/bounded records, JSON round-trip and compiled-import persistence.
No paper-specific names, notation catalogue or Mathlib dependency is built in.

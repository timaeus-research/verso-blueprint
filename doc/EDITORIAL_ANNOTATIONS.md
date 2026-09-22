# Editorial annotations

Import `VersoBlueprint` to use ten native, parameter-free directives. Their
bodies are ordinary Verso blocks: references, mathematics, Lean roles and their
hover information retain their usual rendering. There is no HTML post-processing.

- `:::translation` renders **Notation in Lean**. Use it only for harmless notation
  correspondence, such as `wstar` for the paper's superscript star.
- `:::meta` renders **Formalisation note**. Use it for implementation or editorial
  choices, not mathematical explanations or changes to a theorem.
- `:::formalizationTodo` renders **Formalisation TODO**. Name missing definitions,
  statements, or unsettled correspondence. Describe the current gap neutrally
  and the one or more ways it could resolve, without predictions or preferred
  outcomes. It has no “accepted,” “resolved,” or approval option.
- `:::todoProof`, `:::todoFormulation`, `:::todoHard` render **Formalisation TODO:
  proof work**, **Formalisation TODO: formulation** and **Formalisation TODO: hard**. They
  refine `:::formalizationTodo` by what blocks the paper's statement: only proofs are
  missing and the current definitions suffice (`todoProof`); a Lean formulation of a notion
  of the paper has to be chosen before proofs can start (`todoFormulation`); new mathematics
  or infrastructure is needed, or the question is open (`todoHard`). Each is a TODO in every
  other respect (node header warning, unfolded proofs, `hasFormalizationTodo`).
- `:::clarification` renders **Clarification**. Explain a settled convention
  where the paper is underspecified; state the convention in ordinary mathematics.
- `:::correction` renders **Correction**. Explain a correction and
  link to the counterexample, exact-negation corollary, and corrected statement.
  The label itself supplies no evidence and does not certify the linked proofs.
- `:::deviation` renders **Deviation by choice**. Use it where the paper is neither wrong
  nor underspecified and the formal statement nevertheless differs by the formaliser's
  choice: say whether it is equivalent to or stronger than the paper's and why. Nothing is
  owed on its account; a formal statement that is weaker is a TODO, not a deviation.
- `:::outOfScope` renders **Out of scope**. Explain deliberately omitted material
  and why it is excluded. Material introduced but unused by the paper's results
  is a valid candidate. This is a coverage decision, not a mathematical verdict.

Missing in-scope definitions and statements are TODOs. A TODO may resolve by an
explicit, justified scope exclusion, including for definitions and statements.
Do not exclude prerequisites of a result still claimed in scope: supply them or
explicitly narrow coverage of the affected results too. Scope notes do not hide
nested TODOs or discharge correspondence obligations.
A faithful statement may deliberately have a sorried proof: missing proofs alone
use existing proof-status tracking and do not require a TODO. In a statement-first
document, this also applies to fully specified equivalence and correction claims.
Explicit witnesses, their hypotheses, the original proposition, its exact
negation, and the corrected statement must still be present where required.
Omitted proofs remain correspondence proof obligations, not verified evidence;
say that their formal proofs are omitted. Missing claims or witnesses and
unresolved assumptions or conclusions remain statement TODOs.

Migration: replace `formalizationGap` with `formalizationTodo` and rewrite the
body using the neutral current-state/possible-resolutions convention above.
Regenerate documents and preview manifests: the serialized node flag is now
`hasFormalizationTodo`. Clarification and correction are separate directives,
not approval modes of a TODO.

Put a note concerning a particular theorem or definition inside that node:

````markdown
::::theorem "example"
The mathematical statement, in the paper's formulation.

:::translation
The paper writes a superscript star; Lean uses the suffix `star`.
:::

:::formalizationTodo
The paper states a local threshold; Lean currently states a global threshold.
State the paper's local result, supply an equivalence lemma under its assumptions,
or give an explicit counterexample and exact negation supporting a corrected result.
:::
::::
````

Global implementation or notation notes may be standalone. The directives are
not numbered mathematical nodes and do not change declaration proof status.
Nested TODOs (any of the four TODO kinds) additionally mark the enclosing node's header “Formalisation TODO.”
A proof containing a TODO is not folded. The TODO body remains visible, without
repeated proof-status boilerplate.

A formalisation TODO means missing statement work in the blueprint, not an error in the paper.
Name the omitted claim, altered hypothesis, or missing lemma at the affected
statement or application. An auxiliary definition or a conditional theorem is
not itself a gap merely because it differs from the paper's presentation.
Explain such mathematics in ordinary prose; mark a gap where an application
needs a hypothesis or identification whose required statement is missing or
whose mathematical scope remains unresolved.

Mathematical explanations stay in mathematical prose, and proof explanations in
proof nodes. A nontrivial alternative formulation requires an equivalence
lemma, including assumptions and domains. An assertion that the paper is false
requires an explicit counterexample and a corollary asserting the original
claim's exact negation. These are ordinary linked mathematical nodes, optionally in a
discrepancy appendix; a correction annotation only explains and links them.
Their proofs must establish the claimed correspondence before it can be called
verified. If the complete statements deliberately have omitted proofs, use their
proof status rather than a statement TODO; do not describe the correction as
verified. Until the statements, witnesses and source scope are settled, retain
the TODO warning. A substantive
change of assumptions or conclusions is not a clarification merely because an
author chose it. Meta annotations cannot serve as
evidence that the formalization corresponds to the paper.

Implementation: `src/VersoBlueprint/Editorial.lean`. The theorem/definition
renderer detects nested TODO blocks from the Verso document tree, not
from rendered HTML. CSS hooks are `.bp-editorial` with
`data-kind="translation|meta|formalizationTodo|todoProof|todoFormulation|todoHard|clarification|correction|deviation|outOfScope"`, `.bp-editorial-title`,
`.bp-editorial-content`, and `.bp-correspondence-warning`.

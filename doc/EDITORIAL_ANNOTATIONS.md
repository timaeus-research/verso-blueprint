# Editorial annotations

Import `VersoBlueprint` to use three native, parameter-free directives. Their
bodies are ordinary Verso blocks: references, mathematics, Lean roles and their
hover information retain their usual rendering. There is no HTML post-processing.

- `:::translation` renders **Notation in Lean**. Use it only for harmless notation
  correspondence, such as `wstar` for the paper's superscript star.
- `:::meta` renders **Formalization note**. Use it for implementation or editorial
  choices, not mathematical explanations or changes to a theorem.
- `:::formalizationGap` renders **Formalization gap**. Use it to expose
  an outstanding correspondence obligation, with links to the relevant ordinary
  mathematical nodes. It has no “accepted,” “resolved,” or approval option.

Put a note concerning a particular theorem or definition inside that node:

````markdown
::::theorem "example"
The mathematical statement, in the paper's formulation.

:::translation
The paper writes a superscript star; Lean uses the suffix `star`.
:::

:::formalizationGap
The current Lean statement uses an alternative formulation. The lemma proving
equivalence to the paper's statement has not yet been supplied.
:::
::::
````

Global implementation or notation notes may be standalone. The directives are
not numbered mathematical nodes and do not change declaration proof status.
Nested gaps additionally mark the enclosing node's header “Formalization gap.”
A proof containing a gap is not folded. The gap body remains visible, without
repeated proof-status boilerplate.

A formalization gap means missing work in the anchor, not an error in the paper.
Name the omitted claim, altered hypothesis, or missing lemma at the affected
statement or application. An auxiliary definition or a conditional theorem is
not itself a gap merely because it differs from the paper's presentation.
Explain such mathematics in ordinary prose; mark a gap where an application
needs a hypothesis or identification that has not been established.

Mathematical explanations stay in mathematical prose, and proof explanations in
proof nodes. A nontrivial alternative formulation requires a proved equivalence
lemma, including assumptions and domains. An assertion that the paper is false
requires a counterexample and a corollary proving the original claim's exact
negation. These are ordinary linked mathematical nodes, optionally in a
discrepancy appendix, not annotation kinds. Until those obligations are
established, retain the gap warning. Meta annotations cannot serve as
evidence that the formalization corresponds to the paper.

Implementation: `src/VersoBlueprint/Editorial.lean`. The theorem/definition
renderer detects nested gap blocks from the Verso document tree, not
from rendered HTML. CSS hooks are `.bp-editorial` with
`data-kind="translation|meta|formalizationGap"`, `.bp-editorial-title`,
`.bp-editorial-content`, and `.bp-correspondence-warning`.

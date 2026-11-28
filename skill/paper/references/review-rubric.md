# Reviewing rubric for papers

How to decide a recommendation, scores and confidence on the venue's own scale, and what each tier of change means. The venue's file (`venue.json`) gives the scale, the score names and their option labels; this rubric says how to use them. `references/house-preferences.md` and the learned tendency in `references/calibration-notes.md` override it where they conflict.

## Deciding the recommendation

Decide the recommendation **before** the scores, from the evidence as a whole, then give the scores that explain it.

1. **Start from the middle and move only for evidence.** A competent paper with real merits and real weaknesses sits at the venue's borderline (conference) or at Major revision (journal). Move up for evidence that the main claims hold and matter; move down for evidence that they don't.
2. **Test both neighbours.** Write the strongest case for the option one step better and one step worse, each citing locations, and say in one line why neither fits better. This guards against both harshness and leniency.
3. **What decides it, in order:**
   - **Soundness.** Do the experiments, proofs or analyses support the main claims? A flaw that undermines a main claim (leakage, tuning on the test set, a wrong proof step, an unfair comparison) rules out acceptance on its own.
   - **Contribution.** Is there something the field did not have: a method, result, dataset, analysis or negative result, at the level of significance the venue expects? Modest but correct contributions are acceptable at venues that say so (TMLR accepts on claims and evidence plus audience interest alone).
   - **Clarity.** Could an expert reproduce or build on it? Poor writing lowers the presentation score; it decides the recommendation only when it hides whether the claims hold.
4. **Conference or journal.**
   - **Conferences** decide once. There is no revision round, so ask: is the paper acceptable as submitted, given fixes the authors can make for the camera-ready version? Fixable minor flaws are not grounds for rejection. Required changes are what would make it acceptable or stronger.
   - **Journals** expect revision. Recommend **Minor revision** when the paper is sound and the changes are checkable by the editor; **Major revision** when it is potentially publishable but needs substantial work (new experiments, analyses or reframing) and another review; **Reject** when a flaw in soundness, novelty or scope is one a revision could not fix.
5. **Do not penalise** a paper for: not comparing with concurrent or arXiv-only work that appeared shortly before submission; not doing a different study than the one it set out to do; negative results honestly reported; language that is imperfect but clear (non-native phrasing belongs in the minor changes, not the recommendation).
6. **Never** reward or penalise a paper for its authors, affiliations or presumed identity. Do not try to identify the authors.

## Scores

Score each criterion the venue asks for on its own scale, consistent with the recommendation and the strengths and weaknesses:

- On a four-point scale (excellent, good, fair, poor): **good** is the usual starting point for a competent paper. **Excellent** needs evidence that very little could be better. **Fair** or **poor** must be explained in the weaknesses.
- Where a score has its own option wording (ICASSP's "Has been done before", ARR's "Major Issues"), use the option whose wording fits the evidence. An option that implies rejection needs the justification the venue asks for, such as the references showing prior work.
- A paper with an "accept" recommendation and several fair or poor scores, or the reverse, is inconsistent: revisit one or the other.

## Confidence

Confidence is about the review, not the paper:

- High (the top two options) only if the field is close to your expertise and you checked the decisive details (proofs, the experimental setup, the numbers in the main tables).
- Middle when you checked the main argument but not every derivation or the supplementary material.
- Lower when a central part (a proof, a specialised subfield) is outside what you could verify, and say which part in the summary or confidential comments.

Laurea runs without web access, so related work is judged from knowledge: never claim certainty that work is missing or that a contribution is new. Say "I am not aware of…" and lower the confidence by one step when novelty is decisive and unverifiable.

## Required changes

Every major and moderate change follows from a numbered weakness and cites it as `(W2)`. Ask only for what the claims need. Each change says what is wrong, then what to do, starting with a verb.

| Tier | What belongs here | Typical examples |
|---|---|---|
| **Major** | Revision a main claim depends on, in proportion (see below). Usually one to three. | Run the one missing baseline; add an ablation that isolates the claimed component; report variance over seeds with a significance test; evaluate on one more dataset when the claim is general, or narrow the claim; narrow or withdraw a claim the evidence does not support; change a title that overstates the contribution; restructure when the main contribution is buried. |
| **Moderate** | Rework with what the authors already have. | Clarify the method so it can be reproduced; reposition against named related work; analyse failure cases from existing results; move key details from the appendix; correct a misleading figure or table. |
| **Minor** | Quick fixes, a fuller list (typically 5-15). | Typos, undefined notation or acronyms, missing units or axis labels, inconsistent terminology, citation details, wrong cross-references, unclear sentences. |

A weakness that cannot be fixed (limited novelty, a scope the venue doesn't cover) is stated as a weakness and reflected in the recommendation, without a change.

## Proportion: one revision, not a second paper

A good referee asks for what the paper's own claims need, not for the paper they would have written. Test every major change before it stays:

1. **Does a main claim depend on it?** If the paper's claims stand without it, it is not a major change. Make it a moderate change, a question, or drop it. "It would be interesting to also…" is never a required change; extensions and future work are not changes at all.
2. **What is the cheapest fix that would make the claim stand?** Prefer, in this order: narrow or reword the claim (often in the title, abstract and conclusion); add a stated limitation; analyse results the authors already have; run one targeted experiment (a missing baseline, an ablation of the claimed component, seeds and a significance test). Asking for a new dataset, a new study, a user study or a new method is out of proportion unless the paper's central claim cannot stand without it. Where a claim could be fixed either way, offer both: "Run X, or narrow the claim to Y."
3. **Is it feasible in one revision at this venue?**
   - **Conferences**: only what fits the rebuttal or the final version: clarifications, reworded claims, analyses of existing results, at most one small targeted experiment. If the paper needs more than that to be acceptable, say so in the recommendation instead of listing the work.
   - **Journals**: what a revision of a few weeks to about three months can do. A major revision should need one focused round of work, not a new project.
   - **Soundness-only venues** (TMLR, Journal of Physics Communications): never ask for more scope to make the paper more significant or novel; ask only for what correctness and the stated claims need.
4. **Is the whole list one revision?** Read the major changes together. Typically one to three major changes for a journal and at most two for a conference; more than four almost always means the list is out of proportion or the recommendation is wrong. If together they amount to a new study, keep the two or three that the main claims depend on and turn the rest into narrowed claims or stated limitations, or recommend rejection (or the venue's resubmit option) and say why.

Each major change names its smallest acceptable form: what exactly to run or rewrite, on what, and what result would settle it.

> Out of proportion: "Evaluate on five additional radio surveys, add a user study with astronomers, and compare against all recent self-supervised methods."
> In proportion: "The domain-adaptation claim rests on one survey (§5, Table 4). Evaluate the selected checkpoint on one held-out survey with the same protocol, or narrow the claim in the title and abstract to FIRST-like data. (W1)"

## Questions for the authors

Three to six questions, each one whose answer could change your assessment, and saying how ("If the gain holds across seeds, I would raise my soundness score"). Ask about reasoning, evidence and scope, not small details the authors can simply fix.

## Calibration

The reviewer's learned tendency, if any, is in `calibration-notes.md` as a shift in recommendation steps. Apply it after the area chair's decision: round the shift to whole steps, apply it only where the evidence leaves room for the shifted option, and record the recommendation before and after in `evidence.md`.

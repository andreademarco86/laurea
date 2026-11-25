# Marking rubric and calibration

## Standard

Mark as an external examiner of international standing would: against what strong work at this level looks like at leading universities internationally, and against the current state of the field (not the state of the field when the student's sources were written). Be equally ready to recognise excellent work and to name real weaknesses.

## Generic bands (as % of each criterion's maximum)

| Band | % of the criterion's maximum | Meaning |
|---|---|---|
| Outstanding | 85-100 | Publishable-quality work in this aspect; very little to fault. Rare. |
| Excellent | 70-84 | Strong, rigorous, critical; minor gaps only. |
| Very good | 60-69 | Solid and competent; some moderate weaknesses. |
| Good / satisfactory | 50-59 | Adequate; clear weaknesses but core requirements met. |
| Weak | 40-49 | Partly meets requirements; significant gaps. |
| Inadequate | < 40 | Falls well short of what is expected at this level in this aspect. |

Convert the percentage to whole marks for the criterion's maximum in the current marking scheme (see SKILL.md). Example with the default maxima: "Very good" is 6/10 for (a), 12-13/20 for (b) and 15-17/25 for (c) or (d).

These bands only guide the mark for each criterion. The report gives the marks obtained, never a pass/fail verdict, grade or classification.

## Criterion descriptors

### (a) Introduction and overall document (10)
Look for: clear motivation and problem statement; explicit, measurable aims/objectives/research questions; stated contributions; chapter overview. Document as a whole: logical structure, readable academic English, consistent formatting, figures/tables legible and referenced, consistent citation style, appropriate length, abstract that reflects the actual results.
- High: a reader knows by the end of Ch. 1 exactly what will be done, why, and how success is measured; the document is polished.
- Low: vague aims ("explore deep learning for X"), objectives never revisited, poor language that impedes understanding, sloppy presentation.

### (b) Literature Review (20)
Look for: coverage of foundational and **current** work (for fast-moving CV/ML topics, the last 2-3 years matter); critical synthesis (comparison, trade-offs, gaps) rather than paper-by-paper description; clear link from the gaps identified to the chosen approach; datasets and evaluation practice in the field reviewed; correct, verifiable citations, mostly peer-reviewed or well-established preprints.
- High: organised thematically, compares methods on common axes (often a comparison table), identifies a gap the dissertation then addresses.
- Low: list of summaries, outdated, relies on blogs/websites, no connection to the method; misrepresented or unverifiable references.

### (c) Method and Solution (25)
Look for: justified design choices (why this architecture/loss/dataset/pre-processing, with alternatives considered); clear, reproducible description (data pipeline, splits, model, training details, hyper-parameters, hardware); sound experimental design planned up front; appropriate technical depth and correctness (equations, algorithms); amount and difficulty of the work done (implementation effort, data collection/annotation, system integration). Using existing models is fine at MSc level if the adaptation, integration or study design is well justified.
- High: another MSc student could reproduce it; every major choice is argued; the design actually tests the research questions.
- Low: "we used YOLO because it is popular"; missing training details; methodological flaws (leakage, test-set tuning) designed into the pipeline.

### (d) Testing, Results, Analysis and Evaluation (25)
Look for: appropriate metrics for the task; meaningful baselines and/or comparison with published results on comparable settings; ablations isolating each contribution; variance/statistical robustness (multiple seeds, CIs, significance tests where claims are close); error and failure analysis, qualitative examples; analysis that explains *why*, not just *what*; evaluation against the stated objectives; honest treatment of negative results.
- High: results support the claims rigorously; the student interprets them critically and identifies failure modes.
- Low: a single number with no baseline; tables without discussion; claims of superiority on different data/splits; cherry-picked qualitative examples; results contradict the conclusions.

### (e) Discussion, Conclusion and Future Work (10)
Look for: objectives revisited one by one with evidence; honest limitations (data, generalisation, compute, bias/ethics where relevant); conclusions that follow from the results and are not overstated; specific, motivated future work (not a generic wish-list); reflection on the broader significance or deployment.
- High: a crisp, evidence-backed answer to each research question and a realistic limitations section.
- Low: repeats the abstract; overclaims; future work = "use more data".

## BSc level

Same five criteria, maxima and bands; the expectation behind each band is lower than at MSc:
- (a) A clear problem statement and objectives; tidy, readable document.
- (b) A focused review of the main relevant methods and a few key papers, explained in the student's own words. Breadth and critical synthesis are a bonus, not a requirement.
- (c) A sensible, well-explained design and a correct, working implementation. Using standard tools and pretrained models is entirely acceptable.
- (d) Testing that checks the system works and measures it with suitable metrics against at least a simple baseline; honest reporting of what did not work.
- (e) Conclusions that follow from the results, with realistic limitations and future work.
A well-executed, clearly reported BSc project can sit in the excellent band without any novelty. Rule 2 below applies even more strongly.

## PhD level

Same five criteria, maxima and bands; the expectation behind each band rises:
- (a) The thesis states its original contributions precisely and the chapters form one argument.
- (b) Command of the field: the review is authoritative and positions the contributions against the current state of the art.
- (c) The methods are original or applied in an original way, and are rigorous enough for peer review.
- (d) Evaluation at publication standard: strong baselines, ablations, statistics, uncertainty, external validation.
- (e) A convincing case for the contribution to knowledge, its limits and the research programme it opens.
Rule 2 below ("MSc, not PhD") does not apply at PhD level: novelty is required. Published or submitted papers are evidence of quality, but the examiner still judges the thesis itself.

## Astronomy and astrophysics applications

Judge the ML and the astronomy together. Typical weaknesses that matter: labels from a biased subset applied out of domain, training on simulations with no check on real data, point estimates where calibrated uncertainties are needed, global metrics with no breakdown by magnitude/redshift/SNR, and no comparison with the established non-ML method. See `astro-ml-checklist.md`.

## Computational physics and physics with a computational component

The five criteria and their maxima stay the same; read them in physics terms:
- (c) Method and Solution: the physical model and its assumptions, the choice and implementation of the numerical method, and (for experimental work) the measurement and analysis design.
- (d) Testing, Results, Analysis and Evaluation: verification (convergence studies, test problems, conservation checks), validation against experiment or literature, and the treatment of statistical and systematic uncertainties.
Typical weaknesses that matter: no convergence study, error bars that ignore correlations, results quoted outside the model's regime of validity, verification presented as validation, and "it agrees with the literature" without a quantitative comparison. Machine learning is not expected unless the dissertation uses it; do not penalise a physics dissertation for lacking ML baselines or ablations. See `physics-checklist.md`.

## Calibration rules (apply every time)

1. **Anchor, then move.** Start each criterion at the "very good" band (a solid, competent MSc) and move up or down only for evidence in the log. Write down which evidence moved it.
2. **Mark to the level, not above it** (BSc and MSc). Do not require novelty or state-of-the-art beating results. Reward rigour, insight and honest evaluation. A careful study with negative results can earn a high (d).
3. **Mark what is there.** Do not penalise for not doing a different project. Do penalise for not doing what the dissertation itself promised.
4. **No double penalty.** A flaw is penalised once, in the criterion where it originates (e.g. leakage in the split -> (c); its effect on claimed results is noted in (d) but the main deduction sits in (c)), unless it independently damages both.
5. **Severity scales the deduction.** A *major* validity issue normally caps that criterion at the "good" band; several moderate issues move it down one band; minor issues alone rarely move a band.
6. **Language.** Grammar and style count in (a) only, unless they prevent understanding of a specific section.
7. **Length is not quality.** Do not reward padding; do not penalise concision.
8. **Constraints.** Acknowledged constraints (compute, data access, time) soften, but do not remove, deductions if the student mitigated them sensibly.
9. **Consistency.** Comments must justify the number. If the weaknesses look more serious than the mark implies (or vice versa), change one of them.
10. **Holistic check.** After summing, ask: "Does this total match my overall impression of the dissertation's quality band?" If the sum and the holistic band differ by more than one band, revisit the criteria, then note the resolution in the evidence log.
11. **Uncertainty.** If a judgement depends on something the viva can clarify (e.g. whether the test set was used for early stopping), mark on the evidence in the document, and turn the doubt into a viva question rather than assuming the worst.
12. **Integers only.** Use whole marks.

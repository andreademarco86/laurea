# External research, reference checks and originality (Phase 5)

An examiner of international standing does not judge a dissertation only from inside its own covers. Check it against the current state of the field, check that its references are real and used honestly, and check that the work is the student's own. Record everything in `<work>/external.md`: each search (query, source, date), what you found, and what it means for the marks.

## Query hygiene (always)

- Never put the student's name, supervisor, institution, the dissertation title verbatim, or any personal data in a query.
- Never upload or paste the PDF or long passages anywhere.
- Topic and bibliographic searches: use topic keywords, method names, dataset names and the titles of **cited** papers.
- Phrase checks (only if enabled for this run, see below): at most **8** queries, each an exact phrase of **8-14 words** that is distinctive (not generic boilerplate). No numbers that identify the student's data.
- Prefer scholarly sources (field-specific lists in `domains.md`): arXiv, Semantic Scholar, ACL Anthology, CVF Open Access, OpenReview, PMLR, NASA ADS (astronomy and physics), INSPIRE-HEP (particle and nuclear physics), APS (Physical Review), IOP, AIP and AAS journal pages, IEEE/ACM/Springer landing pages, DBLP, Google Scholar results pages. Use the publication's own page to confirm details.
- If web access is not available in this run, say so in `external.md` and the final message, and do the internal checks only.

## A. Currency of the field and missed work (feeds criterion (b), sometimes (c)/(d))

1. List the 3-6 core topics of the dissertation (problem, method family, datasets, evaluation setting).
2. For each, find the seminal works and the most important work of the last 2-3 years (survey papers are a good entry point). Aim for roughly 10-20 searches in total.
3. Compare with the bibliography. A paper is a **significant omission** only if it is directly relevant and well known (highly cited, a standard baseline or benchmark, or a recent state of the art on the same task). Do not list marginal papers to look thorough.
4. Check "state of the art" claims and baseline choices against published results on the same benchmark and setting. Outdated baselines (e.g. a 2018 model when stronger, easily available models exist) weaken (c)/(d). For physics work, compare the student's key computed or measured quantities with published experimental and computational values for the same system and conditions, and note any unexplained disagreement.
5. In the report: name the 2-5 most important omissions with author(s), year and venue in the (b) weaknesses (verified to exist), and use one as a viva question if it bears on the method or results.

## B. Reference verification (feeds (a) and (b); integrity if serious)

1. Spot-check 10-15 references, choosing: those supporting key claims, any that look odd (wrong venue/year, vague details, unfamiliar titles), and a random few.
2. For each: does it exist with these authors/year/venue? Does it say what the dissertation claims it says (read the abstract at least)?
3. Fabricated or badly misattributed references are serious. They are often a sign of unchecked AI-generated text. Report exact cases with page numbers; do not generalise beyond the evidence.

## C. Originality and plagiarism (high level; never a verdict)

This is a screening for concerns to raise with the examiner, **not** a replacement for the institution's similarity-checking service (e.g. Turnitin) and never an accusation in the report.

Internal signals (always):
- Abrupt changes in voice, spelling convention (UK/US), terminology, notation or referencing style between sections.
- Passages that read like a paper's abstract or textbook prose and carry no citation; definitions or derivations lifted without attribution.
- Figures or tables that look reproduced from a paper or website without "adapted from" credit.
- Method and results suspiciously identical to a public paper or repository (same architecture diagram, same numbers) without acknowledgement.
- Overlap with the student's own prior publications not declared (self-plagiarism rules vary; note, do not judge).
- Signs of unedited generative-AI text (generic filler, confident claims with no evidence, invented details). Report only concrete passages, with pages; detection is unreliable, so frame it as a question.

External checks (if phrase checks are enabled): search up to 8 distinctive phrases, chosen from the passages with the strongest internal signals. Also search for public code repositories or papers matching the specific method name, dataset combination and headline numbers.

Reporting:
- Minor and isolated (e.g. a sentence close to a source that is cited elsewhere): a minor correction ("paraphrase and cite").
- Concerning but uncertain: a weakness under (a) (presentation and academic practice) plus a viva question asking the student to explain the provenance of the specific passage/figure. Keep the tone neutral.
- Serious (substantial verbatim copying from an uncited source, fabricated references, copied results): do **not** put accusations in the report. Put the evidence (sources, phrases, pages) in `external.md` and lead the final message with it so the examiner can follow the institution's academic-integrity procedure. Mark the work on its merits as written, and say that the mark is provisional pending that procedure.

## D. Methodological soundness (feeds (c) and (d))

Beyond the domain checklists, ask as an international reviewer would:
- **Design**: does the experimental design actually answer each research question? Are the hypotheses testable and tested?
- **Validity**: internal (confounds, leakage, tuning on test data), external (would results transfer to other data, sites, instruments, surveys?), construct (do the metrics measure what is claimed?).
- **Statistics**: appropriate tests, variance across runs, confidence intervals, multiple-comparison awareness, effect sizes vs noise.
- **Reproducibility**: could a competent peer reproduce the main result from the dissertation plus released code/data?
- **Claims vs evidence**: is every headline claim (abstract, conclusion) supported by a specific result? Overclaiming is a weakness in (e).

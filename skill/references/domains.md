# Fields covered and which checklists to use

The common thread is AI/ML and computational work in numerate sciences. In Phase 2, identify the dissertation's field(s) here; in Phase 4, apply every checklist listed for those fields. Work that spans fields (e.g. ML for astronomy) gets all relevant checklists, and each part is judged by the standard of its own field.

## Primary fields (full checklists)

| Field | Typical degrees | Checklists |
|---|---|---|
| AI, machine learning and data science | BSc/MSc/PhD in AI, Machine Learning, Data Science, Intelligent Systems | `ml-cv-checklist.md` |
| Computer vision and imaging | as above, plus Imaging, Visual Computing | `ml-cv-checklist.md` |
| Computing and ICT | ICT, Computer Science, Software Engineering, Information Systems, Computer Engineering, Cybersecurity | `computing-checklist.md` (+ `ml-cv-checklist.md` when ML is a main component) |
| Physics and computational physics | Physics, Computational Physics, Applied Physics, Physics with a computational project | `physics-checklist.md` (+ ML checklist when ML is used) |
| Astronomy and astrophysics | Astronomy, Astrophysics, Space Science, Physics and Astronomy | `astro-ml-checklist.md` + `physics-checklist.md` |
| Speech, language and audio processing | Speech and Language Technology, Computational Linguistics, Linguistics with a computational element, NLP, Audio/Acoustic Engineering | `speech-language-checklist.md` (+ ML checklist when ML is used; + computing checklist for system building) |

## Related fields (same direction)

For these, combine the closest primary checklists above with the field-specific checks below. Any of them can become a full checklist (see "Adding a field").

| Field | Use | Field-specific checks |
|---|---|---|
| Electrical and electronic engineering, signal processing, communications | computing + ML | Conditions tested (SNR, channel models, sampling rates); real-time and hardware constraints; standard datasets and simulators; measurement on real hardware when claimed. |
| Robotics, autonomous systems, mechatronics | computing + ML + physics (dynamics) | Simulation-to-real gap; repeated real trials with statistics; safety and failure modes; comparison with classical control or planning baselines. |
| Embedded systems, IoT and edge AI | computing + ML | Latency, memory and energy measured on the target device; effect of quantisation or pruning on accuracy; connectivity and power constraints. |
| Cybersecurity and networking (with ML) | computing + ML | Explicit threat model; realistic and adversarial evaluation; known dataset artefacts (outdated intrusion datasets, duplicate flows); base-rate effects on false positives. |
| Bioinformatics and computational biology | ML + physics (numerics, statistics) | Data provenance and batch effects; leakage across related sequences, samples or patients; multiple-testing correction; biological validation of predictions. |
| Medical imaging and health informatics | ML + computing | Patient-level splits; external validation at another site or scanner; clinically meaningful metrics and operating points; ethics approval, consent and data protection; regulatory awareness. |
| Computational chemistry and materials science | physics + ML | Method and functional choices justified; convergence and benchmark accuracy against experiment or higher-level theory; ML surrogates checked outside the training chemistry. |
| Earth observation, remote sensing and geoinformatics | ML + astro-style data checks | Spatial autocorrelation and region-based splits; sensor and season differences; ground-truth quality; uncertainty of maps. |
| Computational neuroscience and cognitive science | ML + physics (modelling, statistics) | Model-data comparison with appropriate statistics; parameter identifiability; ethics for human or animal data. |
| Applied mathematics, statistics and operations research | physics (numerics) + computing (algorithms) | Correctness of derivations and proofs; complexity and convergence; standard benchmark instances; sensitivity analysis. |
| Quantitative finance and econometrics (with ML) | ML + physics (statistics) | Look-ahead and survivorship bias; transaction costs; regime changes and out-of-time testing; backtest overfitting. |
| Human-computer interaction and human-centred AI | computing (user studies) + ML | Study design and power; validated instruments; ethics and consent; qualitative analysis method; accessibility. |
| Music information retrieval and acoustics | speech-language + ML | Audio and annotation provenance; artist- or recording-level splits; perceptual evaluation design; room and instrument acoustics measured correctly. |
| Clinical and educational speech technology | speech-language + ML | Clinically validated labels; ethics and consent for vulnerable speakers; agreement with expert raters; fairness across speaker groups. |

## Scholarly sources by field (for Phase 5)

- Computing and engineering: IEEE Xplore, ACM Digital Library, USENIX, DBLP, arXiv cs.
- ML and vision: OpenReview, PMLR, CVF Open Access, arXiv cs.LG/cs.CV.
- Speech and language: ISCA Archive (Interspeech), IEEE ICASSP and TASLP, ACL Anthology (incl. LREC), Speech Communication, Computer Speech & Language, JASA, arXiv eess.AS/cs.CL.
- Physics and astronomy: NASA ADS, INSPIRE-HEP, APS, IOP, AIP, AAS, arXiv physics/astro-ph.
- Life sciences and medicine: PubMed, Europe PMC, bioRxiv/medRxiv.
- Earth sciences: AGU, Copernicus journals, ESSOAr/ESS Open Archive.
- Chemistry and materials: ACS, RSC, ChemRxiv.

## Adding a field

To make a related field a full checklist, create `references/<field>-checklist.md` with these sections, then add a row to "Primary fields" above:

1. **Scope**: the degrees and kinds of work it covers, and which other checklists to combine with it.
2. **Data and set-up**: provenance, collection, conditions, ethics.
3. **Method**: what must be justified and reported for the field's standard methods.
4. **Evaluation**: field-standard metrics, baselines, validation and how uncertainty is reported.
5. **Threats to validity**: the field's classic mistakes (the ones an expert examiner looks for first).
6. **Literature**: the canonical works, venues and sources to search.
7. **Level expectations**: BSc, MSc and PhD.

The examiner can also ask for this in plain words in the app's Examining Standards (e.g. "Add a full checklist for robotics dissertations").

---
title: "MSc Dissertation - Examiner's Report"
---

| | |
|---|---|
| **Student name** | Sample Student |
| **Dissertation title** | Spell Checking for a Low-Resource Language |
| **Degree** | MSc in Artificial Intelligence |
| **Institution** | Sample University |
| **Examiner** | Dr Sample Examiner |
| **Recommended dissertation mark** | **62 / 90** |
| **Viva mark** | ______ / 10 |
| **Final mark** | ______ / 100 |

## 1. Summary

The dissertation builds a spell checker for Maltese that combines a finite-state lexicon with a neural re-ranker trained on a newly annotated corpus of learner and web text (§3.1, p. 21). The corpus holds about 40,000 sentences, and the candidate labels 6,000 error pairs by hand using written guidelines (§3.2, p. 24). The system proposes candidates from the lexicon and then ranks them with a small character-level model. It reports a correction accuracy of 87.4% on a held-out test set and compares against Hunspell and a character-level baseline (§5.2, p. 48).

The mark rests first on careful corpus construction (§4.1, p. 30). The annotation guidelines are explicit, and agreement between two annotators is reported and reasonable (Table 4.1, p. 31). The evaluation design is also clear: the test set is kept apart from tuning, and the baselines use the same data (§5.1, p. 46). The literature review covers rule-based and neural spell checking well, with a fair account of work on other low-resource languages (§2.3, p. 15). Against this, all results come from a single test split, with no variance across runs, so the 4-point gain over the baseline may not be reliable (§5.3, p. 52). The error discussion is thin for dialectal forms, which the introduction names as a main motivation (§6.1, p. 60). The conclusion also claims the system is ready for classroom use, which the evaluation does not test (§6.2, p. 63).

The system is carefully built, and the corpus work is the strongest part of the dissertation. It gives Maltese a useful new resource, and the code and data are released for others to use. The evaluation is the main weakness: one test split cannot show that the gain over the baseline is reliable, and the dialect question the work set out to answer is left mostly open. Overall, this is a very good dissertation with a valuable resource at its core, held back by an evaluation that does not yet test its main claims.

## 2. Marking scheme

| Criterion | Max | Mark |
|---|:---:|:---:|
| (a) Introduction and overall document | 10 | 7 |
| (b) Literature Review | 20 | 14 |
| (c) Method and Solution | 25 | 18 |
| (d) Testing, Results, Analysis and Evaluation | 25 | 16 |
| (e) Discussion, Conclusion and Future Work | 10 | 7 |
| **Total** | **90** | **62** |

### (a) Introduction and overall document - 7/10

**Strengths**

- Clear and well-supported point for criterion a (§2.1, p. 11).
- Clear and well-supported point for criterion a (§2.2, p. 12).

**Weaknesses**

- A specific limitation for criterion a that could be addressed (§4.1, p. 31).
- A specific limitation for criterion a that could be addressed (§4.2, p. 32).

### (b) Literature Review - 14/20

**Strengths**

- Clear and well-supported point for criterion b (§2.1, p. 11).
- Clear and well-supported point for criterion b (§2.2, p. 12).

**Weaknesses**

- A specific limitation for criterion b that could be addressed (§4.1, p. 31).
- A specific limitation for criterion b that could be addressed (§4.2, p. 32).

### (c) Method and Solution - 18/25

**Strengths**

- Clear and well-supported point for criterion c (§2.1, p. 11).
- Clear and well-supported point for criterion c (§2.2, p. 12).

**Weaknesses**

- A specific limitation for criterion c that could be addressed (§4.1, p. 31).
- A specific limitation for criterion c that could be addressed (§4.2, p. 32).

### (d) Testing, Results, Analysis and Evaluation - 16/25

**Strengths**

- Clear and well-supported point for criterion d (§2.1, p. 11).
- Clear and well-supported point for criterion d (§2.2, p. 12).

**Weaknesses**

- A specific limitation for criterion d that could be addressed (§4.1, p. 31).
- A specific limitation for criterion d that could be addressed (§4.2, p. 32).

### (e) Discussion, Conclusion and Future Work - 7/10

**Strengths**

- Clear and well-supported point for criterion e (§2.1, p. 11).
- Clear and well-supported point for criterion e (§2.2, p. 12).

**Weaknesses**

- A specific limitation for criterion e that could be addressed (§4.1, p. 31).
- A specific limitation for criterion e that could be addressed (§4.2, p. 32).

## 3. Viva questions

**Q1. Sample viva question 1?** (§5.1, p. 49)

- *Why asked:* To test understanding.
- *Expected / acceptable answer:* A clear explanation with evidence.
- *Weak answer:* A vague answer.

**Q2. Sample viva question 2?** (§5.2, p. 50)

- *Why asked:* To test understanding.
- *Expected / acceptable answer:* A clear explanation with evidence.
- *Weak answer:* A vague answer.

**Q3. Sample viva question 3?** (§5.3, p. 51)

- *Why asked:* To test understanding.
- *Expected / acceptable answer:* A clear explanation with evidence.
- *Weak answer:* A vague answer.

## 4. Substantial corrections

1. §5.3, p. 52: results come from a single test split -> report the mean and spread over five random splits using the existing models.

## 5. Minor corrections

1. p. 41, §3.1: a sample typo -> corrected word
2. p. 42, §3.2: a sample typo -> corrected word
3. p. 43, §3.3: a sample typo -> corrected word
4. p. 44, §3.4: a sample typo -> corrected word
5. p. 45, §3.5: a sample typo -> corrected word

## 6. Declaration

&nbsp;

Signature: ![Signature](signature.png){width=4.5cm}

&nbsp;

Date: ______________________________

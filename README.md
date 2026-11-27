# Laurea

Laurea is a macOS app for dissertation examiners and paper reviewers.
- It drafts examiner's reports for **BSc, MSc and PhD** dissertations, with suggested marks on your institution’s grading scale, page-referenced feedback, viva questions and corrections. You review the draft, decide the marks and export a signed Word report.
- It reviews **journal and conference papers** before submission, as a referee at the target venue would, on that venue's own form and scale: a recommendation, scores, strengths and weaknesses, questions for the authors and required changes.

**[Download the latest Laurea for macOS (.dmg)](https://github.com/andreademarco86/laurea/releases/latest/download/Laurea.dmg)** · [Release notes](https://github.com/andreademarco86/laurea/releases/latest) · [Changelog](CHANGELOG.md)

Requires **macOS 14 Sonoma or later** on Apple silicon or Intel, Apple’s Command Line Tools, and one of:
- a Claude account with access to Claude Code;
- a ChatGPT account with access to Codex;
- a Google account for Gemini CLI. Google AI Pro and Ultra give higher daily limits. Whether a Google Workspace or school account works depends on your organisation’s Gemini settings.

Examination, revision and teaching use your signed-in plan’s allowance and any extra usage enabled on that account. [Claude plan usage](https://support.claude.com/en/articles/15036540-use-the-claude-agent-sdk-with-your-claude-plan) · [Codex subscription sign-in](https://learn.chatgpt.com/docs/auth?surface=cli) · [Gemini CLI quotas](https://github.com/google-gemini/gemini-cli/blob/main/docs/resources/quota-and-pricing.md)

## Install and sign in

1. Download `Laurea.dmg`, open it and drag **Laurea** into **Applications**.
2. Install Apple’s Command Line Tools if needed by running `xcode-select --install` in Terminal.
3. Open Laurea. This build is ad hoc signed. If macOS blocks the first launch and you trust the GitHub download, use **System Settings → Privacy & Security → Open Anyway**. [Apple’s instructions](https://support.apple.com/en-us/102445)
4. In the Setup Assistant, choose **Claude**, **ChatGPT** or **Gemini**, click **Install** if needed and click **Sign In…**. Complete the provider’s sign-in in your browser, then return to Laurea. Gemini CLI runs on Node.js: Laurea uses your Mac’s Node.js 20 or later if you have it, or installs its own copy.
5. Set your name, institution, marking weights and optional signature. You can change these later in **Settings**.

To update, quit Laurea and replace the copy in **Applications**. Your examinations, settings, signature and calibration are kept. A new version starts from its own examining standards, so anything taught in an earlier version is cleared.

## Review a dissertation

1. Drop a PDF into Laurea or press **⌘N**. Choose **BSc**, **MSc** or **PhD** and click **Examine**. The sidebar shows the examination’s progress.
2. Open the draft when it’s ready. Click any page reference to check it against the dissertation: the PDF panel opens at that page with the quoted passage, or the figure or table label, highlighted. If neither appears, Laurea lightly highlights the sentence that best matches the comment, but only when one sentence clearly stands out.
3. Edit the text, and raise or lower individual marks with their arrows; **Your Adjustment** shows how far the total has moved from the proposed mark. The header shows the percentage and grade on your scale: for the final mark once you add the viva mark, and for the dissertation mark until then. Press **⇧⌘R** to request a revision.
4. Add the viva mark after the oral. Press **⌘S** to save as you go. When the report is final, click **Export Word Report…** at the end of the report (or press **⇧⌘E**). Laurea produces the Word report only then: signed with your signature, with the viva and final marks, from the report as you left it, saves it with the examination and shows it in Finder. Export asks for the viva mark and your signature if either is missing. **Date the report** under **Declaration** is on by default, so an undated report is dated on the day you export it. Pick another date, or turn it off to sign and date by hand.

## Review a paper

1. Click **New Paper Review…** (**⇧⌘N**) or drop a paper PDF into Laurea and choose **Papers to Review**.
2. Choose the target venue: a conference such as NeurIPS, ICML, ICLR, ACL Rolling Review, CVPR or Interspeech, or a journal such as TMLR, IEEE TPAMI, Pattern Recognition, the Physical Review journals, Journal of Physics Communications or MNRAS. **Other conference** and **Other journal** use general scales. Click **Review Paper**.
3. Check the draft. Click the venue's scale to change the recommendation (a dot marks the proposal), and adjust the scores and confidence. Edit the text as you would a report; page references open the paper at the cited page.
4. Under **Copy and Export**, copy each field, or the whole review laid out as the venue's form (**⇧⌘C**), or export a Word copy.

The review contains:
- a summary close to its word limit, ending in an overall assessment, with no page references;
- numbered strengths and weaknesses (W1, W2, …), most important first, each with its location;
- three to six questions for the authors whose answers could change the assessment;
- required changes in three tiers, each tied to a weakness: **major** (new experiments, baselines, statistical tests, narrowed claims or a new title, only where a claim depends on them), **moderate** (rework with existing results) and **minor** (quick fixes);
- limitations and broader impact, ethical concerns, and confidential comments to the area chair or editor;
- the recommendation, scores and confidence on the venue's own scale.

It is written in your voice as an anonymous reviewer. Three reviewers read each paper independently, looking closely at **soundness**, **novelty** and **clarity**; an area chair settles disagreements. Their ratings are under **Internal notes**. Novelty is judged without web access, so the review never claims for certain that related work is missing.

## What the report contains

- **Summary**:
  - Close to its word limit (350 words by default), in three paragraphs: what the work is, what drives the mark, and a closing assessment of the dissertation as a whole.
  - No page references; the details are in the criteria.
  - Refers to “the candidate”, never the student by name.
- **Marks and comments**: marks for five weighted criteria, each with page-referenced strengths and weaknesses, most important first.
- **Viva questions**:
  - 3–5 for a BSc, 4–6 for an MSc and 8–10 for a PhD, each with why it is asked and what good and weak answers look like.
  - They are broad questions about methodology, outcomes, knowledge of the field and limitations, not small details.
- **Substantial corrections**: rework that needs real effort but no new research, each following from a weakness. There may be none.
- **Minor corrections**: quick fixes, written plainly for the student: what is wrong, then what to do.
- **Declaration**: your signature and the date.

The report is written in your voice as the examiner. It gives marks only, never a grade or classification. In the editor, the summary, strengths and weaknesses, viva questions and corrections each fold away.

## How Laurea examines

Laurea extracts the PDF text and checks for hidden text on your Mac, then the examination engine reads the dissertation, reviews its figures and tables, and drafts the report. Laurea produces the Word file locally.

Three examiners read each dissertation independently. Each reads all of it but looks closely at a different part:
- **Methods**: the method and results.
- **Field**: the literature and the work’s place in its field.
- **Holistic**: the argument as a whole and whether the conclusions follow.

Each gives an overall grade before marking the criteria, deciding the grade the evidence supports and then a mark within its range. The chair weights each criterion towards the examiner who leads on it. Any criterion where they disagree by a grade or more is settled by weighing the case for the grade above against the case for the grade below.

Open **Internal notes** at the bottom of the report editor to see:
- each examiner’s marks and overall grade;
- the chair’s marks before calibration;
- a one-line view from each examiner;
- the ruling on each disputed criterion.

The exported report presents only the agreed findings and marks.

**Thoroughness** is under **Settings → Engine**:
- **Adaptive** is the default. It maps the front matter at Light effort and examines at Standard. It asks for a focused Thorough second opinion, shown under **Internal notes**, when the examiners’ marks differ by more than 15% of a criterion’s maximum or cite conflicting evidence.
- **Standard** is a fixed single pass.
- **Light** suits simple revisions.
- **Thorough** gives deeper technical analysis throughout.

Revisions reuse the existing report and evidence, reopening only the pages the change needs.

## Settings

- **General**: your name, institution and signature, and links to your examinations, examining standards and calibration notes.
- **Marking**:
  - The marking scheme: each criterion’s weight is its maximum mark, and the criteria and the viva add up to 100.
  - Your **Grading Scale**: **University of Malta** by default, or **International**. You can edit the grades, their lower bounds and what each means.
  - The summary length.

  Each examination keeps the weights, scale and summary length it started with.
- **Engine**: the signed-in subscription (Claude, ChatGPT or Gemini), model and thoroughness. Gemini offers **Adaptive** and **Standard** thoroughness.

## Examining standards and calibration

Laurea covers AI and machine learning, computing and ICT, speech and language processing, physics, astronomy, and related computational fields. [Full list of supported fields](skill/references/domains.md)

In **Examining Standards** (**⇧⌘L**), describe a standing preference, such as asking a viva question about reproducibility. Your changes are saved on your Mac and can be undone until you install a new version of Laurea.

**Calibration** (**⇧⌘K**) learns from how you change the proposed marks, separately for each degree level and criterion. For papers, it learns one tendency across all venues from how you change the proposed recommendation (**Calibration → Papers**).
- An adjustment needs at least three examinations in which you changed that mark in the same direction.
- Marks you accept unchanged don’t count towards that minimum, but can strengthen an adjustment that points the same way.
- Recent decisions carry more weight, and the evidence in the current dissertation takes priority.

Use **Evidence for learned offsets** to see how many examinations support each adjustment.

## Dissertation data

Laurea sends the material needed for each examination, review or revision to your selected provider. Paper reviews are meant for checking a paper before submission. Using one to referee someone else's submission is your responsibility: many venues don't allow sharing submissions under review, or ask you to declare it. Your account’s training and retention settings apply. App runs disable web searches and local provider session history. Examinations, settings, your signature, calibration history and anything you teach are stored on your Mac in `~/Library/Application Support/Laurea`; the examining standards themselves are part of the app. [Claude data usage](https://code.claude.com/docs/en/data-usage) · [ChatGPT and Codex data controls](https://help.openai.com/en/articles/7730893-data-controls-in-chatgpt) · [Gemini Code Assist for individuals privacy notice](https://developers.google.com/gemini-code-assist/resources/privacy-notice-gemini-code-assist-individuals)

## Troubleshooting

- **The engine cannot start.** Install Apple’s Command Line Tools. The engine log is at `~/Library/Application Support/Laurea/engine.log`.
- **Examination stops before starting.** Open **Settings → Engine** and check that the selected engine is installed and signed in.
- **Gemini asks you to sign in again.** Open **Settings → Engine** and click **Sign In…**. If a Google Workspace or school account cannot sign in, your organisation has not enabled Gemini CLI for it; use a personal Google account.
- **Export asks for your signature.** Add it in **Settings → General**, then export again.
- **Export says the Word report could not be produced.** Read the message, fix any problem it lists, save with **⌘S**, then export again.
- **The checker says a cited page doesn’t exist.** For PDFs without built-in page numbers, Laurea reads them from the page text and repairs numbers that break the sequence. If a page is still missing, check the citation against the PDF.

[Build from source and development guide](DEVELOPMENT.md)

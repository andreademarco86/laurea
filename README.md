# Laurea

Laurea is a macOS app for dissertation examiners. It drafts reports for **BSc, MSc and PhD** dissertations, with suggested marks on your institution’s grading scale, page-referenced feedback, viva questions and corrections. You review the draft, decide the marks and export a signed Word report.

**[Download the latest Laurea for macOS (.dmg)](https://github.com/andreademarco86/laurea/releases/latest/download/Laurea.dmg)** · [Release notes](https://github.com/andreademarco86/laurea/releases/latest) · [Changelog](CHANGELOG.md)

Requires **macOS 14 Sonoma or later** on Apple silicon or Intel, Apple’s Command Line Tools, and one of:
- a Claude account with access to Claude Code;
- a ChatGPT account with access to Codex;
- a Google account for Gemini CLI. Google AI Pro and Ultra give higher daily limits. Google Workspace and school accounts also need a Google Cloud project from your IT department.

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
3. Edit the text and individual marks, or use **Overall Calibration** to adjust the total. The header shows the total’s percentage and grade on your scale. Press **⇧⌘R** to request a revision.
4. Add the viva mark after the oral. Press **⌘S** to save and **⇧⌘E** to export the Word report. Exporting confirms the report. **Date the report** under **Declaration** is on by default, so an undated report is dated on the day you export it. Pick another date, or turn it off to sign and date by hand. Export always uses a Word file produced from the current report; if it can’t be produced, nothing is exported.

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

The report is written in your voice as the examiner. It gives marks only, never a grade or classification. In the editor, the viva questions and corrections fold away.

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
- **Engine**: the signed-in subscription (Claude, ChatGPT or Gemini), model and thoroughness. Gemini offers **Adaptive** and **Standard** thoroughness, and a **Google Cloud project** field for Workspace and school accounts.

## Examining standards and calibration

Laurea covers AI and machine learning, computing and ICT, speech and language processing, physics, astronomy, and related computational fields. [Full list of supported fields](skill/references/domains.md)

In **Examining Standards** (**⇧⌘L**), describe a standing preference, such as asking a viva question about reproducibility. Your changes are saved on your Mac and can be undone until you install a new version of Laurea.

**Calibration** (**⇧⌘K**) learns from how you change the proposed marks, separately for each degree level and criterion.
- An adjustment needs at least three examinations in which you changed that mark in the same direction.
- Marks you accept unchanged don’t count towards that minimum, but can strengthen an adjustment that points the same way.
- Recent decisions carry more weight, and the evidence in the current dissertation takes priority.

Use **Evidence for learned offsets** to see how many examinations support each adjustment.

## Dissertation data

Laurea sends the material needed for each examination or revision to your selected provider. Your account’s training and retention settings apply. App runs disable web searches and local provider session history. Examinations, settings, your signature, calibration history and anything you teach are stored on your Mac in `~/Library/Application Support/Laurea`; the examining standards themselves are part of the app. [Claude data usage](https://code.claude.com/docs/en/data-usage) · [ChatGPT and Codex data controls](https://help.openai.com/en/articles/7730893-data-controls-in-chatgpt) · [Gemini Code Assist for individuals privacy notice](https://developers.google.com/gemini-code-assist/resources/privacy-notice-gemini-code-assist-individuals)

## Troubleshooting

- **The engine cannot start.** Install Apple’s Command Line Tools. The engine log is at `~/Library/Application Support/Laurea/engine.log`.
- **Examination stops before starting.** Open **Settings → Engine** and check that the selected engine is installed and signed in.
- **Gemini asks you to sign in again.** Open **Settings → Engine** and click **Sign In…**. With a Google Workspace or school account, enter the **Google Cloud project** your IT department gives you (with Gemini Code Assist enabled) under Gemini in **Settings → Engine**, then sign in again.
- **The Word export is missing your signature.** Add it in **Settings → General** and save the report again.
- **Export says the Word document could not be produced.** Read the message at the top of the report, fix any problem it lists, save with **⌘S**, then export again.

[Build from source and development guide](DEVELOPMENT.md)

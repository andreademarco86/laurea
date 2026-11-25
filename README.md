# Laurea

Laurea is a macOS app for dissertation examiners. It drafts reports for **BSc, MSc and PhD** dissertations, with suggested marks, page-referenced feedback and viva questions. You review the draft, decide the marks and export a signed Word report.

**[Download Laurea for macOS (.dmg)](https://github.com/andreademarco86/laurea/releases/latest/download/Laurea.dmg)** · [Release notes](https://github.com/andreademarco86/laurea/releases/latest)

Requires **macOS 14 Sonoma or later** on Apple silicon or Intel, Apple’s Command Line Tools, and a Claude or ChatGPT account with access to Claude Code or Codex. Examination, revision and teaching use your signed-in plan’s allowance and any extra usage enabled on that account. [Claude plan usage](https://support.claude.com/en/articles/15036540-use-the-claude-agent-sdk-with-your-claude-plan) · [Codex subscription sign-in](https://learn.chatgpt.com/docs/auth?surface=cli)

## Install and sign in

1. Download `Laurea.dmg`, open it and drag **Laurea** into **Applications**.
2. Install Apple’s Command Line Tools if needed by running `xcode-select --install` in Terminal.
3. Open Laurea. This build is ad hoc signed. If macOS blocks the first launch and you trust the GitHub download, use **System Settings → Privacy & Security → Open Anyway**. [Apple’s instructions](https://support.apple.com/en-us/102445)
4. In the Setup Assistant, choose **Claude** or **ChatGPT**, click **Install** if needed and click **Sign In…**. Complete the provider’s sign-in in your browser, then return to Laurea.
5. Set your name, institution, marking weights and optional signature. You can change these later in **Settings**.

If you already use Laurea, quit it and replace the copy in **Applications**. Existing examinations and examiner preferences are stored separately in Application Support. This release preserves your installed examining standards and teaching history. The bundled defaults are used for fresh installations.

## Review a dissertation

1. Drop a PDF into Laurea or press **⌘N**. Choose **BSc**, **MSc** or **PhD** and click **Examine**.
2. Open the draft when it’s ready. Click a page reference to check it against the dissertation in the PDF panel. Edit the text and individual marks, or use **Overall Calibration** to adjust the total. Press **⇧⌘R** to request a revision.
3. Add the viva mark after the oral. Press **⌘S** to save and **⇧⌘E** to export the Word report.

The report includes a summary, strengths and weaknesses by criterion, suggested viva questions with expected answers, and minor corrections. In **Settings** you can set the summary limit (350 words by default) and the marking scheme. Each examination keeps the weights it started with.

## Examining standards

Laurea covers AI and machine learning, computing and ICT, speech and language processing, physics, astronomy, and related computational fields. Its bundled workflow checks for hidden text, links headline claims to evidence, and uses several marking passes to reconcile scores against the rubric. [Full list of supported fields](skill/references/domains.md)

In **Examining Standards** (**⇧⌘L**), describe a standing preference, such as asking a viva question about reproducibility. Teaching history is saved on your Mac and can be undone. **Calibration** (**⇧⌘K**) shows how your adjustments influence future drafts at each degree level.

## Dissertation data

Laurea sends the material needed for each examination or revision to your selected provider. Your account’s training and retention settings apply. App runs disable web searches and local provider session history. Saved examinations, the signature and detailed calibration history are stored on your Mac. [Claude data usage](https://code.claude.com/docs/en/data-usage) · [ChatGPT and Codex data controls](https://help.openai.com/en/articles/7730893-data-controls-in-chatgpt)

## Troubleshooting

- **The engine cannot start.** Install Apple’s Command Line Tools. The engine log is at `~/Library/Application Support/Laurea/engine.log`.
- **Examination stops before starting.** Open **Settings → Examination Engine** and check that the selected engine is installed and signed in.
- **The Word export is missing your signature.** Add it in **Settings → Examiner** and save the report again.

[Build from source and development guide](DEVELOPMENT.md)

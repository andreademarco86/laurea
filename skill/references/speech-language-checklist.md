# Speech, language and audio processing: technical checklist

Use for dissertations in speech processing, spoken language technology, computational linguistics and NLP, phonetics and phonology with a computational element, and audio/acoustic signal processing. Typical work: speech recognition (ASR), text-to-speech and voice conversion, speaker and language recognition, speech enhancement and separation, emotion and paralinguistics, pronunciation and clinical speech assessment, dialogue systems, machine translation, low-resource and under-documented languages, and phonetic or corpus studies. Combine with `ml-cv-checklist.md` when ML is a main component and `computing-checklist.md` for system building. Skip items that do not apply. Log every hit with section, page and severity.

## Data and corpora
- Corpora named with version, size (hours, utterances, speakers, words), licence and access route (e.g. LDC, ELRA, Common Voice, OpenSLR, institutional collections).
- Recording conditions described: microphones, rooms, channels, sampling rate and bit depth, codecs, noise; how they match the intended use.
- **Speaker-independent splits**: no speaker (or session, or recording) appears in both training and test unless the task is explicitly speaker-dependent. Text overlap between training and test prompts also checked.
- Coverage of accents, dialects, ages, genders and languages reported; bias and representativeness discussed. For low-resource languages, orthography, normalisation and data collection effort described.
- Annotation: transcription conventions, phonetic alphabet (IPA, SAMPA/X-SAMPA), guidelines, annotator expertise, and inter-annotator agreement (e.g. Cohen's or Fleiss' kappa, Krippendorff's alpha).
- Ethics: consent for voice recordings, voice as biometric (special-category) data under GDPR, anonymisation, data storage and sharing; extra care for clinical, child or vulnerable speakers.

## Signal processing
- Sampling, resampling and anti-aliasing correct; pre-emphasis, framing, window type and length, hop size stated and justified.
- Features described and appropriate (spectrograms, filterbanks, MFCCs, pitch, formants, energy, learned features), with normalisation (e.g. CMVN) applied without test-set leakage.
- Filters and transforms correct (filter design, phase, STFT/iSTFT consistency, overlap-add); units and scales (Hz, mel, Bark, dB) used correctly.
- Data augmentation realistic (noise, reverberation, speed perturbation, SpecAugment) and kept out of the test set.
- Real-time or streaming claims backed by latency and real-time-factor measurements on stated hardware.

## Models and methods
- Choice of model family justified (HMM/GMM, hybrid DNN-HMM, CTC, attention or transducer models, self-supervised encoders, neural vocoders, LLM-based systems) against alternatives.
- Pretrained models (e.g. wav2vec 2.0, HuBERT, WavLM, Whisper, multilingual LLMs) named with version and checkpoint; fine-tuning details reported; **contamination** considered (has the pretrained model already seen the test data?).
- Language models, lexicons and pronunciation dictionaries described, including how out-of-vocabulary words are handled.
- Toolkits and recipes (Kaldi, ESPnet, SpeechBrain, NeMo, fairseq, Hugging Face) cited, with configuration changes stated.
- Linguistic analysis: theoretical framework stated; phonetic measurements (formants, F0, durations) taken with stated tools (e.g. Praat) and settings; statistical models suited to the design (often mixed-effects models with speakers and items as random effects).

## Evaluation
- Field-standard metrics, computed correctly:
  - ASR: WER/CER with the **text normalisation** stated (case, punctuation, numbers); per-condition breakdown (noise, accent, speaker).
  - Speaker and language recognition: EER and minDCF with the cost parameters; trial lists and their difficulty.
  - Enhancement and separation: PESQ, STOI/ESTOI, SI-SDR, DNSMOS, with the reference signals described.
  - TTS and voice conversion: MOS/CMOS, MUSHRA, ABX or preference tests, plus objective measures (MCD, F0 RMSE, intelligibility via ASR WER) and speaker similarity.
  - NLP and translation: task-standard metrics (accuracy/F1, BLEU, chrF, COMET, BERTScore) with their known limits acknowledged.
- **Listening tests**: protocol following recognised practice (e.g. ITU-T P.800, ITU-R BS.1534 MUSHRA), number and screening of listeners, randomisation, anchors and hidden references, listening environment, confidence intervals and significance tests.
- Strong, current baselines on the same data; comparisons with published numbers only on identical test sets and normalisation.
- Statistical significance for close results (e.g. bootstrap or matched-pairs tests for WER differences).
- Error analysis: confusions, failure cases by speaker group, accent, noise type or linguistic category; qualitative examples (audio samples or spectrograms).

## Literature (for criterion (b))
- Covers the signal-processing, linguistic and ML traditions the work draws on, and recent work (last 2-3 years) in this fast-moving area.
- Venues and sources: ISCA Archive (Interspeech, Speech Prosody, SSW, Odyssey), IEEE ICASSP and IEEE/ACM Transactions on Audio, Speech and Language Processing, ACL Anthology (ACL, EMNLP, NAACL, EACL, COLING, LREC), Speech Communication, Computer Speech & Language, JASA, Journal of Phonetics.
- For less-resourced languages, prior corpora, tools and linguistic descriptions of the language are cited.

## Level expectations
- **BSc**: a sound pipeline built with standard tools on a clear task, evaluated with the correct metric on a proper speaker-independent split, with honest discussion.
- **MSc**: as BSc, plus justified design choices against current methods, careful evaluation (per-condition breakdowns, significance, listening tests where quality is claimed) and critical reflection.
- **PhD**: a novel model, method, resource or linguistic finding, evaluated at the standard of Interspeech/ICASSP/ACL-level work, with a clear contribution to the field.

# ML / computer vision technical checklist

Use against the method and results chapters. Not every item applies; skip what is irrelevant to the project. Log every hit with section, page and severity (major / moderate / minor).

## Data
- Source, licence and size of each dataset stated; class distribution reported.
- **Splits**: how train/val/test were made; are they disjoint at the right unit (patient, subject, video, scene, location, time) - not just at frame/image/crop level? Near-duplicates across splits? (Classic CV leakage: adjacent video frames, augmented copies, same patient.)
- Pre-processing/normalisation statistics fitted on training data only.
- Annotation: who labelled, guidelines, inter-annotator agreement for custom data; label noise acknowledged.
- Class imbalance handled (sampling, loss weighting) and reflected in metric choice.
- Ethics: personal/biometric/medical data, consent, anonymisation, GDPR; dataset bias and representativeness.

## Model and training
- Architecture choice justified against alternatives; pre-training source stated (ImageNet, COCO, CLIP...); freeze/fine-tune strategy explained.
- Loss function appropriate to the task (e.g. focal/dice for imbalance, contrastive setup details).
- Hyper-parameters reported; how they were tuned - **on validation data, not test**.
- Early stopping / model selection on validation set only.
- Augmentation described and appropriate (no label-breaking augmentations, e.g. horizontal flips for left/right-sensitive tasks or text).
- Training details: epochs, batch size, optimiser, LR schedule, hardware, training time; convergence shown (curves) and over/under-fitting discussed.
- Input resolution and its effect on small objects (detection/segmentation).
- For LLM/VLM/foundation-model projects: prompt design documented, contamination risk of benchmarks, API/model versions pinned, evaluation not done by the same model without validation.

## Evaluation
- Metric suits task: classification (accuracy is misleading under imbalance -> per-class P/R/F1, balanced accuracy, AUROC/AUPRC); detection (mAP@0.5 and @0.5:0.95, per-class AP, IoU thresholds stated); segmentation (mIoU, Dice, boundary metrics); tracking (MOTA, IDF1, HOTA); generation (FID/KID with sample counts, plus human or task-based evaluation); regression (MAE/RMSE with units); retrieval (Recall@K, mAP).
- Baselines: at least a simple/standard baseline; comparisons on the **same data and splits**; published numbers quoted only for comparable settings.
- Ablations isolate each claimed contribution.
- Robustness: multiple seeds or cross-validation; mean +/- std or CIs; significance testing where differences are small.
- Error analysis: confusion matrix, failure cases, per-class / per-condition breakdown (lighting, occlusion, scale, domain).
- Generalisation: held-out domain, external test set, or at least discussion of domain shift.
- Efficiency where relevant to the claims: parameters, FLOPs, latency/FPS on stated hardware, memory - especially for "real-time" or "edge" claims.
- Qualitative results representative, not cherry-picked (are failures shown?).
- Explainability (Grad-CAM etc.) used to support claims, not as decoration; its limitations acknowledged.

## Experimental design and validity
- Each research question maps to an experiment that can answer it; hypotheses stated before results where appropriate.
- Baselines are current and properly tuned (equal tuning budget for proposed method and baselines).
- Threats to validity discussed: internal (leakage, confounds), external (other datasets, domains, sites), construct (metric fits the claim).
- Statistical robustness proportionate to the claim: repeated runs, confidence intervals, significance tests for close comparisons, no p-hacking via many unreported variants.

## Claims and reproducibility
- Numbers in abstract/conclusion match results tables.
- Each objective / research question is answered with evidence.
- Claims of "state of the art", "real-time", "robust", "generalises" are actually demonstrated.
- Code/data availability stated; enough detail to reproduce.
- Statistical language is used correctly ("significant" only with a test).
- Use of third-party code and generative-AI tools acknowledged as required.

## Literature-review specifics for CV/ML
- Covers the canonical lineage relevant to the task (e.g. CNN -> ViT; two-stage -> one-stage -> DETR-style detectors; FCN/U-Net -> transformer segmenters; foundation models such as SAM/CLIP/DINO where relevant).
- Includes recent work (last 2-3 years) for active areas.
- Discusses benchmark datasets and evaluation conventions of the subfield.
- Citations are real and support the claims made; flag any that look fabricated or misattributed (spot-check by title only).

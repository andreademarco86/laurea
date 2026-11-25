# ML in astronomy / computational astrophysics: technical checklist

Use alongside `ml-cv-checklist.md` when the work applies ML/AI to astronomical data or simulations: photometric redshifts, galaxy morphology, transient/variable classification, exoplanet detection in light curves, strong-lensing searches, radio (RFI flagging, source finding), spectral classification, anomaly detection in surveys, emulators and simulation-based inference (SBI) for cosmology, denoising/deconvolution, solar physics, gravitational-wave data. Skip items that do not apply. Log every hit with section, page and severity.

## Data, surveys and labels
- Survey and data release named and cited (e.g. SDSS DR17, Gaia DR3, DES, ZTF, Rubin/LSST, Euclid, JWST, Kepler/TESS, LOFAR/MeerKAT/SKA precursors); query/cuts reproducible (ADQL/SQL, quality flags, magnitude limits).
- **Selection effects**: training labels usually come from a brighter or biased subset (e.g. spectroscopic redshifts, citizen-science votes). Is the model applied outside that domain (fainter, higher-z, different survey depth)? Is this covariate shift measured or at least discussed?
- **Sim-to-real gap**: when trained on simulations (N-body, hydro, mock catalogues, injected signals), is performance on real data checked, and are simulation assumptions (cosmology, noise model, PSF, instrument response) stated?
- Label provenance and quality: Galaxy Zoo vote fractions vs hard labels, catalogue cross-match errors, classifications by heuristic pipelines used as "ground truth".
- **Leakage**: neighbouring sky regions, overlapping image cut-outs, multiple epochs of the same object, or the same simulation box/seed split across train and test. Prefer splits by sky region, object or simulation run.
- Class imbalance for rare events (transients, lenses, anomalies) and its effect on metrics; base rates in the real survey vs the training set.
- Pre-processing physically sensible: units, flux vs magnitude, extinction/dereddening, normalisation that does not erase physical information, handling of missing bands, upper limits and masked pixels.

## Methods
- Choice of representation justified (images, light curves with irregular sampling, spectra, catalogue features, graphs, point clouds) and suited to the data's cadence and noise.
- Irregular time sampling and heteroscedastic errors handled properly (e.g. Gaussian processes, attention with time encodings, error-aware losses) rather than naively interpolated.
- **Uncertainty quantification**: astronomy usually needs calibrated uncertainties, not just point estimates. Probabilistic outputs, posterior calibration, coverage tests for SBI/NPE, PIT histograms or CRPS for photo-z.
- Physics-informed constraints or priors where relevant, and whether they are actually enforced.
- Comparison with the traditional method of the field (template fitting, matched filtering, BLS for transits, SExtractor/PyBDSF for source finding, MCMC likelihood analysis), not only with other ML models.

## Evaluation
- Field-standard metrics: photo-z (bias, sigma_NMAD, catastrophic outlier fraction), classification (completeness/purity per class, ROC/PR), detection (injection-recovery completeness vs SNR/magnitude, false-positive rate per field), parameter inference (bias, coverage, posterior width vs truth), image tasks (flux/shape conservation, residuals).
- Performance reported **as a function of** the physically relevant variables (magnitude, redshift, SNR, size, cadence), not just a single global number.
- Validation on an independent survey, sky region or simulation suite.
- Robustness to realistic systematics (PSF variation, seeing, calibration offsets, RFI, cosmic rays).
- Scientific usefulness shown: does the result enable or improve a science measurement, and at what scale (inference cost per object for survey-scale data)?

## Literature (for criterion (b))
- Covers both the astronomy context (the science question, existing catalogues and pipelines) and the ML lineage used.
- Cites the relevant survey/instrument papers and the established non-ML methods it competes with.
- Recent work (last 2-3 years) in this active field; NASA ADS is the usual index, and arXiv astro-ph preprints are normal in astronomy, but key claims should rest on refereed work.

## PhD-level additions (if the level is PhD)
- Clear original contribution to knowledge in astronomy and/or ML, stated and defended.
- Evidence of publication-quality work (papers, preprints, released code/catalogues) and how the thesis chapters relate to them; the candidate's own contribution to co-authored papers made clear.
- Coherent thesis narrative linking chapters, not a stapled set of papers.

# Computational physics and physics with a computational component: technical checklist

Use when the dissertation is in computational physics, or is a physics dissertation whose results rest on simulation, numerical methods or substantial data analysis. Typical work: finite-difference/finite-element/spectral PDE solvers, molecular dynamics, Monte Carlo (classical and quantum), lattice models, electronic structure (DFT, tight binding), N-body and plasma codes, fluid dynamics, quantum computing simulations, numerical relativity, analysis of experimental or observational data, and ML applied to physics (surrogates, emulators, physics-informed networks). Use `ml-cv-checklist.md` as well when ML is a main component, and `astro-ml-checklist.md` for astrophysics. Skip items that do not apply. Log every hit with section, page and severity.

## Physical model
- Governing equations, Hamiltonian or model stated explicitly, with every symbol defined and units given.
- Approximations and assumptions named (e.g. Born-Oppenheimer, mean field, ideal gas, non-relativistic, periodic boundaries, continuum limit), with their regime of validity, and the parameters studied actually lie inside that regime.
- Boundary and initial conditions stated and physically justified.
- Dimensional analysis and non-dimensionalisation correct; characteristic scales (length, time, energy) identified.
- Conservation laws and symmetries of the model identified, so the numerics can be checked against them.

## Numerical method
- Choice of method justified against alternatives (accuracy, stability, cost), not just "the package does it".
- Discretisation described: grid or basis, time integrator, order of accuracy.
- Stability conditions respected (e.g. CFL condition, stiff problems handled with implicit or adaptive schemes).
- Integrators suit the physics (e.g. symplectic or time-reversible integrators for long Hamiltonian runs; energy drift reported).
- Precision and round-off considered where they matter (cancellation, ill-conditioned matrices, very long runs).
- Random numbers: generator named, seeds recorded, independent streams for parallel runs.
- For established codes (LAMMPS, GROMACS, Quantum ESPRESSO, VASP, CP2K, FEniCS, OpenFOAM, Athena++, Gadget and similar): version, input files and key settings (cut-offs, k-point grids, pseudopotentials, functionals, thermostats, convergence thresholds) reported and cited correctly.

## Verification (is the code solving the equations correctly?)
- Tested against analytic solutions, known limits or standard benchmark problems before production runs.
- **Convergence study**: results shown to converge as resolution improves (grid spacing, time step, basis size, particle number, cut-off, k-points), with the observed order compared to the expected order (Richardson extrapolation where suitable).
- Conservation and symmetry checks (energy, momentum, charge, particle number, detailed balance) monitored and reported.
- Method of manufactured solutions or unit tests for home-written solvers.

## Validation (is the model right for the physics?)
- Results compared with experiment, established literature values or higher-level theory, under the same conditions.
- Disagreements analysed honestly (model limitations vs numerical error vs parameter choice) rather than explained away.
- Verification is not presented as validation, or the other way round.

## Statistics and uncertainty
- Monte Carlo and MD: equilibration or thermalisation shown and discarded; autocorrelation times estimated; error bars from blocking, jackknife or bootstrap that respect correlations (not naive standard errors).
- Finite-size and finite-time effects studied, ideally with extrapolation or finite-size scaling.
- Statistical and systematic uncertainties separated and both reported; uncertainty propagated correctly to derived quantities.
- Fits: model justified, chi-squared per degree of freedom and residuals reported, parameter uncertainties and correlations given, fit range not tuned to get the answer.
- Significance claims made carefully (look-elsewhere effect, multiple comparisons, blinding where it is standard in the field).

## Experimental or observational data analysis
- Data provenance, calibration and selection cuts described and justified.
- Background estimation and systematic effects treated explicitly.
- Detector or instrument effects (resolution, efficiency, acceptance) accounted for, or unfolding described.
- Comparison between data and simulation done like for like (same cuts, same resolution effects).

## ML used for physics
- Physical constraints and symmetries built in or checked (conservation, invariances, equivariance, positivity).
- Surrogates and emulators compared against the conventional solver on held-out regions of parameter space, with the speed-up and accuracy trade-off stated honestly.
- Extrapolation outside the training regime tested or clearly flagged as a limitation.
- Uncertainty of ML predictions quantified when they feed into physical conclusions.

## Performance and software (when computational efficiency is claimed)
- Speed-up and scaling claims backed by measurements: strong and weak scaling for parallel codes, hardware stated, baseline implementation fair.
- Code available (repository or appendix), version-controlled, with input files and scripts needed to reproduce the main figures.
- Testing evidence for home-written code.

## Presentation of results
- Axes with quantities and units; error bars on every measured or sampled quantity; log scales where the physics spans orders of magnitude.
- Numbers quoted with sensible significant figures and uncertainties.
- Figures and tables show the convergence and validation evidence, not just the final result.

## Literature (for criterion (b))
- The physics context: the open question, the established theory and the experimental state of the art.
- The method lineage: standard textbooks and method papers for the numerical approach used, and recent work (last 2-3 years) on the same system or method.
- Previous computational studies of the same system, with their numbers compared to the student's.

## Level expectations
- **BSc**: a standard method implemented correctly and verified on a test problem, applied to a well-defined system, with honest uncertainty estimates.
- **MSc**: as BSc, plus convergence studies, careful uncertainty analysis, validation against literature, and critical discussion of the model's limits.
- **PhD**: new physics results or a new or substantially improved method, verified and validated at publication standard, with a clear contribution to the field.

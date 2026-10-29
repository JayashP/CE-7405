# Changelog

This file records every notable change to the source, tests and project records. Format based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/). Dates are ISO 8601.

## [0.2.0-M2] — 2026-10-29 (branch `claude/m2-indeterminate-beams`)

Milestone M2: indeterminate beams with uniform loads. Source and tests were written by Claude Code.

### Added — engine
- `src/model/meshSpans.m`: node coordinates for multi-span beams, with an exact node at every support.
- `src/model/elementsBetween.m`: element indices between two node coordinates.
- `src/model/addUniformLoad.m`: uniform load w [N/m] (+ up) on all or selected elements; repeated loads superpose.
- `src/loads/equivalentDistributedLoad.m`: consistent element load vector w·[L/2, L²/12, L/2, −L²/12].
- `src/loads/elementLoadVectors.m`: the NE-by-4 matrix of f_e0 for all elements.
- `src/loads/assembleLoadVector.m`: global equivalent load vector, nodal plus element loads.
- `src/postprocess/sampleInternalForces.m`: sampled V(x) and M(x) per element; parabolic M under uniform load, jumps at nodes kept.

### Changed — engine
- `createBeamModel`: new field `model.loads.elementUDL` (NE-by-1, zeros); `meta.formatVersion` changed from 1 to 2.
- `validateModel`: validates `loads.elementUDL`.
- `recoverElementForces`: f_e = k_e·q_e − f_e0, which removes the M1 nodal-loads-only limitation for uniform loads.
- `solveStaticModel`: assembles F with `assembleLoadVector` and returns `results.elementLoads`.

### Added — tests and tools (20 new tests; 46 in total)
- `tests/testMeshSpansAndLoads.m` (9 tests): meshing, element selection, consistent load vector (checked against literals and Gauss integration), superposition, load resultants, invalid input.
- `tests/testUniformLoadBeams.m` (4 tests): simple span and fixed-fixed beam under uniform load, including the single-element case with no free DOFs; element-end equilibrium of the sampled diagrams.
- `tests/testProppedCantilever.m` (3 tests): central point load; **Benchmark C**; mesh independence for ne = 1, 2, 4, 16.
- `tests/testContinuousBeam.m` (4 tests): point loads at both midspans; **Benchmark D**; one span loaded (uplift); unequal spans checked by the three-moment equation.
- `tools/mutation_check.py`: 5 M2 faults added, 12 in total.

### Added — records
- DECISIONS D-015 (uniform load) and D-016 (indeterminate benchmark set). D-005, D-009, D-012 and D-014 updated.
- VERIFICATION_LOG V-002 (M1 in MATLAB R2026b, run by the user) and V-003 (M2 in Octave).
- Raw evidence in `results/verification/`: the M1 MATLAB summary screenshot, the M2 Octave log and the M2 mutation output.

### Verified
- **GNU Octave 8.4.0:** 46 of 46 tests passed. Benchmarks C and D errors are ≤ about 4e‑11 % (target 0.5 %). Mutation check: 12 of 12 faults detected.
- **MATLAB:** M1 26/26 (R2026b, V-002). **M2 tests: NOT RUN.**

### Known limitations
- Point loads inside elements: not implemented (M3).
- Deflection between nodes is not recovered.
- Loads must start and end on nodes.
- Prescribed nonzero support settlement is not supported.

## [0.1.1] — 2026-10-29

### Changed — records
- `DECISIONS.md` D-001: the user chose `JayashP/CE-7405` as the home repository (2026-10-29). It was empty when attached, so nothing was merged or overwritten. M1 is the first commit on `main`.
- `DEVELOPMENT_PLAN.md`: replaced the "not linked to GitHub" risk with the rule to push work to `JayashP/CE-7405`.

No source or test changes.

## [0.1.0-M1] — 2026-10-29

First verified solver milestone (M1). Source and tests were written by Claude Code.

### Added — engine (`src/`, internal SI units, sign convention in DECISIONS.md D-003)

**`src/elements/`**
- `beamElementStiffness.m`: exact 4×4 Euler–Bernoulli element stiffness for DOFs `[v1 θ1 v2 θ2]`, with input validation.

**`src/model/`**
- `generateUniformMesh.m`: uniform node coordinates on [0, L]. The endpoints are exact, and so is the midspan when ne is even.
- `createBeamModel.m`: model struct built from node coordinates and per-element (or scalar) EI.
- `supportRestraint.m`: maps pin and roller to [v], and fixed to [v θ].
- `addSupport.m`: adds a support at a node; rejects duplicates and unknown types.
- `addNodalLoad.m`: nodal force (+ up) and couple (+ CCW).
- `findNodeAtX.m`: converts a coordinate to a node and errors if no node is there (no silent snapping).
- `validateModel.m`: checks the structure and values of the model struct.
- `elementDofs.m`: element-to-global DOF map.
- `assembleGlobalK.m`: sparse triplet assembly of K = Σ A_eᵀ k_e A_e, also returning the element matrices.

**`src/loads/`**
- `assembleNodalLoadVector.m`

**`src/solver/`**
- `partitionDofs.m`: free/restrained partition with an exact rigid-body-mode stability check (`BridgeFE:underRestrained`).
- `solveStaticModel.m`: solves K_ff U_f = F_f with backslash, and reports rcond and equilibrium diagnostics.
- `recoverReactions.m`: R = (KU − F) at the restrained DOFs.
- `recoverElementForces.m`: end actions k_e q_e, plus end shear and moment in the beam sign convention. Nodal loads only.

**`src/util/`**
- `assertPositiveFiniteScalar.m`, `assertFiniteRealScalar.m`, `assertIntegerScalarInRange.m`

### Added — tests and tools

**Root**
- `addProjectPaths.m`
- `runAllTests.m`: runs on MATLAB through `matlab.unittest`, and on Octave through the portable runner. Exits nonzero on failure.

**`tests/`**
- Script-based tests: `testBeamStiffness.m`, `testAssembly.m`, `testSupportsAndStability.m`, `testCantileverTipLoad.m`, `testSimplySupportedBeam.m` (Benchmark A). 26 tests in total.

**`tests/helpers/`**
- `runScriptTestsPortable.m`, `compareToReference.m`, `reportComparisons.m`, `assertThrows.m`, `buildSimplySupportedCentralLoad.m`

**`tools/`**
- `mutation_check.py`: injects 7 single faults into scratch copies of the repo and confirms the tests detect each one.

### Added — records

- `PROJECT_SPEC.md`: verbatim copy of the uploaded handoff spec.
- `README.md`, `DECISIONS.md` (D-001 … D-014), `DEVELOPMENT_PLAN.md`, `VERIFICATION_LOG.md` (V-001), `CHANGELOG.md`, `.gitignore`.
- `results/verification/2026-10-29_M1_octave-8.4.0_runAllTests.log`: raw test log.
- `results/verification/2026-10-29_M1_mutation_check_octave-8.4.0.txt`: raw mutation-check output.

### Verified

- **GNU Octave 8.4.0:** 26 of 26 tests passed. Benchmark A errors are at most about 1.3e‑9 % (target 0.1 %). Mutation check: 7 of 7 faults detected.
- **MATLAB: NOT RUN.** MATLAB is not available in the Claude Code environment.

### Known limitations

- Loads may act at nodes only. In-element loads, UDL and moving vehicles are not implemented (M2–M4).
- Element force recovery omits member-load terms. This is correct only while all loads are nodal (DECISIONS.md D-009).
- Only zero prescribed support displacements are supported.
- The model is a single continuous beam with no internal hinges.
- Indeterminate benchmarks C and D and moving-load Benchmark B: NOT RUN (not implemented).
- No GUI, plotting, materials layer or damage features.

### Deliberately not added

- No placeholder files for Stage 2, 3 or 4, the GUI or visualization (spec §11: create folders lazily).

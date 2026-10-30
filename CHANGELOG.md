# Changelog

This file records every notable change to the source, tests and project records. Format based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/). Dates are ISO 8601.

## [0.4.0-M4] — 2026-10-30 (branch `claude/m4-moving-vehicle-envelopes`)

Milestone M4: multi-axle vehicles moved quasi-statically across the beam, with envelopes, critical vehicle positions and step refinement. Source and tests were written by Claude Code.

### Added — engine
**`src/loads/`**
- `createVehicle.m` and `validateVehicle.m`: axle magnitudes (positive = down), spacings front to rear; the front axle is the reference.
- `vehicleAxlePositions.m`: axle coordinates and signed forces for front-axle position x_v; direction +1 or −1.
- `generateVehiclePositions.m`: equally spaced positions from entry to full exit; the actual step is ≤ the requested step.

**`src/movingload/`**
- `prepareMovingLoad.m`: assembles K, partitions the DOFs and **factorizes K_ff once (Cholesky)**; stores the permanent loads and the station mapping.
- `analyzeVehiclePosition.m`: response at one position. Axles off the bridge are ignored; an axle at a node is a nodal force; an axle inside an element acts through its Hermite vector. Gives U, R, end actions, and V (both limits), M and v at the stations and under the axles.
- `mapCoordinatesToElements.m`: element and local position for the left and right limits.
- `runMovingLoad.m`: the full sweep. Envelopes (M, V, v, with the governing x_v), reaction envelopes, global critical positions (quantity, value, x, x_v, axle positions) and step refinement around each critical position.

### Added — tests and tools (13 new tests; 74 in total)
- `tests/testVehicleAndPositions.m` (4 tests): axle coordinates in both directions, position grids, on-bridge policy, invalid input.
- `tests/testMovingLoadFastPath.m` (2 tests): the fast path against the verified static engine at 14 positions; the case with no axle on the bridge.
- `tests/testMovingLoadEnvelopes.m` (7 tests):
  - single-load envelopes against influence lines
  - two-axle absolute maximum moment
  - step convergence within its theoretical bound
  - spec 3-axle truck
  - two-span negative moment and uplift
  - superposition with a permanent uniform load
  - mirror symmetry of the two travel directions
- `tools/moving_load_reference_check.py`: independent brute-force confirmation of the three closed-form moving-load references, not using the MATLAB code.
- `tools/mutation_check.py`: 8 M4 faults added (26 in total).

### Added — records
- DECISIONS D-019 (vehicle and positions), D-020 (fast solution) and D-021 (envelopes, critical positions, refinement). D-012 and D-014 updated.
- VERIFICATION_LOG V-007.
- Raw evidence in `results/verification/`: the M4 Octave log, the M4 mutation output and the reference brute-force output.

### Verified
- **GNU Octave 8.4.0:** 74 of 74 tests passed. Moving-load benchmark errors are ≤ about 1e‑5 % (target 0.5 %). Fast path vs static engine ≤ 2.5e‑13. Mutation check: 26 of 26 faults detected.
- **MATLAB:** M1–M3 confirmed by the user (V-002, V-004, V-006). M4 confirmed afterwards (V-008, 74/74).

### Known limitations
- No dynamic or impact effects, load or lane factors, or code load models. The analysis is quasi-static only (D-019, D-021).
- The vehicle can only be a sequence of point axles (no distributed lane load moving with it).
- Envelopes are evaluated at stations. Values between stations are not enveloped, but the global critical search also covers the points under every axle.

## [0.3.0-M3] — 2026-10-29 (branch `claude/m3-in-element-point-loads`)

Milestone M3: point loads at any position inside elements, shear jumps, deflection between nodes, and Benchmark B. Source and tests were written by Claude Code.

### Added — engine
- `src/elements/beamShapeFunctions.m`: cubic Hermite N1–N4 at normalized positions r in [0, 1].
- `src/loads/equivalentPointLoad.m`: consistent vector P·[N1 N2 N3 N4]ᵀ for a load at distance a inside an element.
- `src/model/addPointLoad.m`: point load at any global x (+ up); off-beam positions throw `BridgeFE:offBeam`.
- `src/loads/locatePointLoads.m`: resolves each load to a node (within 1e‑9·L) or to an element and local position.
- `src/postprocess/evaluateDeflection.m`: deflection at any x, as the Hermite interpolation plus the exact fixed-fixed particular solution for uniform and point loads.

### Changed — engine
- `createBeamModel`: new field `model.loads.point` (NP-by-2 `[x Fv]`); `meta.formatVersion` changed from 2 to 3.
- `validateModel`: validates point loads, including that every load is on the beam.
- `elementLoadVectors`: includes the Hermite vectors of interior point loads.
- `assembleLoadVector`: adds point loads that sit on nodes.
- `sampleInternalForces`: rewritten to add point-load jumps in V and kinks in M, sampling both sides of each load.
- `recoverElementForces`: help text only (V_j and M_j are the limits at x_j⁻).
- `solveStaticModel`: returns `results.pointLoads`.
- `runAllTests`: no longer echoes `ans = 1xN struct array` when called as a command.

### Added — tests and tools (15 new tests; 61 in total)
- `tests/testShapeFunctionsAndPointLoads.m` (8 tests): shape-function nodal values, rigid-body reproduction, fractions at r = 1/3 and end slopes; fixed-end actions; resultants; load location; F assembly; invalid input.
- `tests/testMovingPointLoad.m` (2 tests): **Benchmark B** over 88 positions on an 8-element mesh, plus continuity across a node.
- `tests/testPointLoadsInElements.m` (5 tests):
  - two loads inside one simply supported element
  - an indeterminate propped cantilever with a load inside an element
  - deflection between nodes for uniform and point loads
  - equilibrium of mixed loads and the size of the shear jumps
  - a load exactly on a support
- `tools/mutation_check.py`: 6 M3 faults added (18 in total). The M2 sampling mutant was moved to the rewritten code line; it injects the same fault.

### Added — records
- DECISIONS D-017 (point loads at arbitrary positions) and D-018 (Benchmark B setup). D-005, D-009 and D-014 updated.
- VERIFICATION_LOG V-005 (M3 in Octave).
- Raw evidence: `results/verification/2026-10-29_M3_octave-8.4.0_runAllTests.log` and `results/verification/2026-10-29_M3_mutation_check_octave-8.4.0.txt`.

### Verified
- **GNU Octave 8.4.0:** 61 of 61 tests passed. Benchmark B errors are ≤ about 7e‑12 % (target 0.5 %). Mutation check: 18 of 18 faults detected.
- **MATLAB:** M1 (V-002), M2 (V-004) and M3 (V-006, 61/61, recorded after the user's run) confirmed by the user.

### Known limitations
- Point couples inside elements are not supported (none are needed for vehicles).
- `evaluateDeflection` gives deflection only, not rotation, between nodes.
- Multi-axle vehicles, position stepping, envelopes and step refinement: M4.

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
- **MATLAB:** M1 26/26 (R2026b, V-002). M2 46/46 (V-004, run by the user after the branch was pushed).

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

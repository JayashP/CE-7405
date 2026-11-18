# DEVELOPMENT_PLAN — milestones and gates (deadline 24 Nov 2026)

This plan follows `PROJECT_SPEC.md` §12 and §17. A milestone counts as complete only when its tests have **executed** and passed, with the evidence recorded in `VERIFICATION_LOG.md`. Dates are working targets.

Order is fixed by the spec:

1. verified solver
2. moving loads
3. envelopes
4. materials
5. basic GUI
6. Stage 2
7. then, only if time allows, Stage 3 and Stage 4

## Status overview (2026-10-29)

| ID | Milestone | Target dates | Status |
|---|---|---|---|
| M1 | Element, assembly, supports, static solve, reactions, nodal-load force recovery, Benchmark A | Oct 28 – Nov 1 | **Done.** 26/26 tests pass in GNU Octave 8.4.0 (V-001) and MATLAB R2026b (V-002) |
| M2 | Indeterminate beams: span mesher, propped cantilever, two-span continuous, UDL, Benchmarks C and D | Nov 2 – 7 | **Done.** 46/46 tests (incl. M1) pass in GNU Octave 8.4.0 (V-003) and MATLAB (V-004). Merged to `main` |
| M3 | Point loads anywhere inside elements (Hermite), interior V/M/deflection recovery, Benchmark B | Nov 8 – 10 | **Done.** 61/61 tests (incl. M1–M2) pass in GNU Octave 8.4.0 (V-005) and MATLAB (V-006). Merged to `main` |
| M4 | Multi-axle vehicle, position stepping, envelopes, critical positions, step refinement | Nov 10 – 13 | **Done.** 74/74 tests (incl. M1–M3) pass in GNU Octave 8.4.0 (V-007) and MATLAB (V-008). Merged to `main` |
| M5 | Steel / RCC input layer (E_s·I_s, E_c·I_eff) and equal-EI equivalence test | Nov 14 – 15 | **Done.** 82/82 tests (incl. M1–M4) pass in GNU Octave 8.4.0 (V-009) and MATLAB (V-010). Merged to `main` |
| M6 | Basic App Designer GUI over the verified engine (sage green, conventional supports, matrix inspection) | Nov 13 – 17 | **Done.** Octave: 95/95 tests, app check 27/27 against stand-ins (V-011). MATLAB: 95/95 tests, app check 27/27, all 5 tabs working (V-012). Merged to `main`; the layout tweaks from the screenshots still need a visual glance |
| M7 | Stage 2: prescribed EI loss, healthy vs degraded comparison, redistribution on an indeterminate beam | Nov 18 – 20 | **Done.** 104/104 in Octave (V-013) and MATLAB (V-014). Merged to `main`. Next, as chosen by the user on 2026-11-10: Damage tab (M7b), then Stage 3 |
| M7b | Damage tab in the app (D-026) | Nov 10 – 11 | **Done.** Octave 106/106, app check 32/32 (V-015); MATLAB 106/106, app check 33/33, tab used (V-016). Merged to `main` |
| M7c | Damage-tab display revisions after V-016 (D-027) | Nov 10 | Octave 107/107, app check 33/33 (V-017); MATLAB with S3b (V-020). Merged to `main` |
| S3 | Stage 3 inverse search (stretch) | Nov 10 – 14 | Engine done in Octave (V-018); revised with the user's options 3 + 2 and an independent review (D-029, V-019). MATLAB 129/129 (V-020). Merged to `main`. Next: app tab (M8) |
| M8 | Identification (Stage 3) tab in the app (D-030) + display fixes | Nov 12 – 18 | **Done.** Octave (V-021); MATLAB 135/135, app check all PASS, tab used (V-022). Merged to `main` |
| M8b | Cosmetic follow-ups (−0.000 in Envelopes tables, readings table width, quieter app check) | Nov 18 | Octave 135/135, app check 48/48 (V-023). **MATLAB: NOT RUN** |
| S4 | Stage 4 steel repair categories from sourced rules (stretch, last) | Only if time remains and sources are chosen | Deferred |
| — | Stabilize, demo recording, final documentation | Nov 21 – 23 | — |
| — | **Submission** | **Nov 24** | — |

## M1 — done (Octave V-001 and MATLAB R2026b V-002)

**Delivered**
- `beamElementStiffness`, `elementDofs`, `assembleGlobalK`
- `createBeamModel`, `generateUniformMesh`, `addSupport`, `supportRestraint`, `addNodalLoad`, `findNodeAtX`, `validateModel`
- `assembleNodalLoadVector`
- `partitionDofs` (with an exact under-restraint check), `solveStaticModel`, `recoverReactions`, `recoverElementForces`
- 26 script-based tests, the runner, and the mutation check

**MATLAB confirmation:** done by the user in R2026b, 26/26 tests (VERIFICATION_LOG.md V-002).

## M2 — indeterminate beams (done; Octave V-003, MATLAB V-004)

**Delivered (2026-10-29):** `meshSpans`, `elementsBetween`, `addUniformLoad`, `equivalentDistributedLoad`, `elementLoadVectors`, `assembleLoadVector` and `sampleInternalForces`. `recoverElementForces` now uses f_e = k_e·q_e − f_e0. Twenty new tests are in `testMeshSpansAndLoads`, `testUniformLoadBeams`, `testProppedCantilever` and `testContinuousBeam`.
The gate is met in Octave: Benchmarks C and D errors are ≤ 4e‑11 %, the point-load indeterminate checks are within 0.1 %, and all 26 M1 tests still pass (VERIFICATION_LOG.md V-003).

**MATLAB confirmation:** 46/46 tests passed on the user's computer (V-004). Merged into `main`.

The original plan for M2 is kept below for traceability.

**Recommended order**

1. **Span-based mesh.** Add `meshSpans(spanLengths, elementsPerSpan)` returning node coordinates with a node at every support. Add a helper that places supports by coordinate (`findNodeAtX` already refuses off-node coordinates).
2. **Indeterminate checks with nodal loads only.** No new load type yet; this isolates the indeterminate solve itself.
   - Propped cantilever (fixed at A, roller at B), central P: R_B = 5P/16, R_A = 11P/16, M_A = −3PL/16, M under the load = +5PL/32.
   - Two equal spans with P at each midspan: R_A = R_C = 5P/16, R_B = 11P/8, M_B = −3PL/16.
   - Both are standard textbook results. Write them as fixed references in the tests.
   - An exploratory scratch run on 2026-10-29 (Octave, not a recorded test and not in `tests/`) reproduced all five ratios with the M1 code to 10 decimals. M2 must still add them as proper tests.
3. **Uniformly distributed member load.** Add `equivalentDistributedLoad`, the consistent vector f_e0 = w·[L/2, L²/12, L/2, −L²/12] with w signed (+ up).
   - Change `recoverElementForces` to f_e = k_e·q_e − f_e0 (DECISIONS.md D-009).
   - Add interior V(x) and M(x) for the UDL case (linear V, parabolic M).
4. **Benchmarks.**
   - Benchmark C, propped cantilever with UDL: R_A = 5wL/8, R_B = 3wL/8, M_A = −wL²/8.
   - Benchmark D, two-span with UDL: M_B = −wL²/8, R_A = R_C = 3wL/8, R_B = 5wL/4.
   - Also check zero deflection at the prop, zero rotation at the fixed end, and equilibrium.

**Gate:** Benchmarks C and D within the spec target of 0.5 %, the nodal-load indeterminate checks within 0.1 %, and all M1 tests still passing.

## M3 — point loads inside elements (Benchmark B) — done (Octave V-005, MATLAB V-006)

**Delivered (2026-10-29):** `beamShapeFunctions`, `equivalentPointLoad`, `addPointLoad`, `locatePointLoads` and `evaluateDeflection` (deflection at any x, exact inside loaded elements). Point loads are now included in `elementLoadVectors` and `assembleLoadVector`, and `sampleInternalForces` shows shear jumps at interior loads.

Tests: 15 new, in `testShapeFunctionsAndPointLoads`, `testMovingPointLoad` (Benchmark B) and `testPointLoadsInElements`.

**Gate met in Octave (V-005):**
- Benchmark B over 88 positions, largest error 7e‑12 % (target 0.5 %).
- The critical position is found at L/2 (500 kN·m).
- Results are continuous across a node.
- All 46 earlier tests still pass.

**MATLAB confirmation:** 61/61 tests passed on the user's computer (V-006). Merged into `main`.

The original plan is kept below for traceability.

- Add `beamShapeFunctions` (Hermite N1–N4 with r = a/L_e) and `equivalentPointLoad`, f_e0 = P·[N1 N2 N3 N4]ᵀ. Loads are **not snapped** to nodes.
- Recover V and M inside loaded elements from element equilibrium, using the end actions plus the real point loads. Shear must jump by P at the load, and M must be piecewise linear.
- **Technical note:** inside a loaded element, interpolating the nodal DOFs with Hermite functions is *not* the exact deflection. The fixed–fixed particular solution of the in-element load must be added. This matters later for sensor deflections in Stage 3.
- **Benchmark B:** a single load at many positions on a simple span, including positions inside elements, exactly at element boundaries and at supports.
  - R_A = P(L−a)/L, R_B = Pa/L, M(a) = Pa(L−a)/L.
  - The maximum moment occurs at a = L/2.
  - Target 0.5 %.

## M4 — vehicle, envelopes and critical positions — done (Octave V-007, MATLAB V-008)

**Delivered (2026-10-30):**
- Vehicle and positions: `createVehicle`, `validateVehicle`, `vehicleAxlePositions`, `generateVehiclePositions`.
- Fast solution: `prepareMovingLoad` (factorize once), `analyzeVehiclePosition`, `mapCoordinatesToElements`.
- Sweep: `runMovingLoad`, which gives envelopes, critical positions and step refinement.

Tests: 13 new, in `testVehicleAndPositions`, `testMovingLoadFastPath` and `testMovingLoadEnvelopes`.

**Gate met in Octave (V-007):**
- Single-load envelopes equal the influence-line maxima.
- Two axles: absolute maximum moment 801.02475 kN·m (exact 801.025).
- Spec 3-axle truck: 1349.1024 kN·m (exact 1349.1025) at x = 9.74 m.
- Two-span: M_B,min = −PL/(6√3) and R_A uplift reproduced.
- Superposition and direction mirroring are exact.
- The fast path matches the static engine to 2.5e‑13.
- Step convergence is within its theoretical bound.
- All 61 earlier tests still pass.

**MATLAB confirmation:** 74/74 tests passed on the user's computer (V-008). Merged into `main`.

The original plan is kept below for traceability.

- **Vehicle struct:** axle magnitudes (positive downward input, converted to −P), spacings, and one documented reference axle. The policy for axles exactly at the bridge ends or supports must be decided and recorded in DECISIONS.md.
- **Position stepping:** from fully off the bridge to fully off again.
- **Envelopes and critical positions:** M, V and δ envelopes as max/min over positions at each x. Track the quantity, sign, x, the vehicle position x_v and the axle set separately.
- **Step refinement:** refine the step near the extremes.
- **Efficiency:** factorize K_ff once and reuse it for every position.
- **Tests:** single-axle reduction to Benchmark B, superposition of multiple axles, axles entering and leaving, and convergence with step size.

## M5 — materials — done (Octave V-009, MATLAB V-010)

**Delivered (2026-10-30):**
- `defineMaterial` (steel E_s·I_s or RCC E_c·I_eff, with a basis note and a unit-sanity warning), `validateMaterial` and `assignMaterial` (per element or per span).
- `createBeamModel(x, material)`.
- The EI-vs-material consistency check in `validateModel`.

Tests: 8 new, in `testMaterials`.

**Gate met in Octave (V-009):**
- Equal-EI steel and RCC models give bit-identical static results and identical envelopes.
- A uniform EI change scales deflections only.
- A mixed steel/RCC two-span beam matches the three-moment equation with two EI values (M_B = −484.375 kN·m).
- All 74 earlier tests still pass.

**MATLAB confirmation:** 82/82 tests passed on the user's computer (V-010). Merged into `main`.

The original plan is kept below for traceability.

- Input layer: steel (E_s, I_s) or RCC (E_c, I_eff supplied by the user). Both produce EI per element, and there is no material branch inside the solver.
- **Test:** steel and RCC models with equal assigned EI give identical results. This checks input and solver consistency, **not** concrete behaviour.
- No nonlinear cracking.

## M6 — basic GUI — done (Octave V-011, MATLAB V-012)

**Delivered (2026-10-30):**
- The code-built app `app/BridgeConditionApp.m` with 5 tabs (D-023).
- GUI helpers in `src/gui/`; drawing primitives and plot helpers in `src/visualization/`; `modelWithVehicle` and `defaultEnvelopeStations`.
- 13 new suite tests (`testGuiHelpers`, `testDrawingGeometry`).
- The scripted app check `tests/gui/checkBridgeConditionApp.m`.
- Development checks: `tools/gui_mock` (Octave stand-ins) and `tools/preview` (matplotlib previews).

**Open actions for the user, in MATLAB:**
1. `runAllTests` (expected 95 passed).
2. `checkBridgeConditionApp(true)` (expected all PASS).
3. `app = BridgeConditionApp;` and a screenshot of each tab.

Layout or style changes requested from the screenshots will be made before merging to `main`.

The original plan is kept below for traceability.

- An App Designer front end that calls only `src/` functions.
- Sage-green styling. Conventional pin, roller and fixed-wall symbols.
- Inspection views for k_e, K, the free and restrained DOFs, F, U and R.
- **Needs MATLAB.** Claude Code cannot run or check App Designer in this environment, so GUI behaviour must be confirmed by the user. The numerical engine stays callable without the GUI.

## M7 — Stage 2 — done (Octave V-013, MATLAB V-014)

**Delivered (2026-11-05):**
- `src/damage/`: `applyStiffnessDamage`, `effectiveEI`, `relativeChange`, `compareHealthyDamaged`, `damageSensitivity`.
- Every EI used in a calculation now goes through `effectiveEI`.
- 9 new tests in `testStiffnessDamage`.
- Mutation check: 5 M7 faults added. One survived at first and exposed a test gap; a new test now closes it.

**MATLAB result:** 104/104 (V-014). The user chose a Damage tab (M7b) before Stage 3.

## M7b — Damage tab — done (Octave V-015, MATLAB V-016)

- Tab "Damage (Stage 2)" (D-026), 5 helpers, 2 plotting functions, drawing highlight.
- 2 new tests (106), 6 new app-check rows (32), 7 mutants all detected.

**Open actions for the user, in MATLAB:** on branch `claude/m7b-damage-tab`, run `runAllTests` (expected 106 passed) and `checkBridgeConditionApp(true)` (expected 33 rows PASS), then open the app, go to the Damage tab, press Apply damage, Compare and Run sensitivity, and send a screenshot.

The original plan is kept below.

- `applyStiffnessDamage(model, element, d)` with EI_D = (1−d)·EI_0 and 0 ≤ d < 1.
- **Tests:**
  - d = 0 reproduces the healthy result.
  - Only the chosen element changes.
  - Forces in the simple span are unchanged while deflections change.
  - Reactions and moments in the continuous beam redistribute.
- Report percentage changes only when the healthy value is nonzero (spec §6).

## Known risks carried forward

- In-element load force recovery and interior deflection (M3) is the highest-risk numerical item. It must be verified across element boundaries.
- No MATLAB in the Claude Code environment. Every MATLAB- or GUI-specific behaviour needs a run by the user.
- Work done in a cloud container must be pushed to `JayashP/CE-7405` before the session ends (DECISIONS.md D-001).

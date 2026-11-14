# DECISIONS — CE 7405 Matrix-Based Bridge Analysis Platform

`PROJECT_SPEC.md` records agreed intentions. This file records decisions made while implementing them.
Demonstrated capability is recorded only in `VERIFICATION_LOG.md`.

**Status labels**
- **ACCEPTED**: in force and implemented. Changing it needs a new entry.
- **PROVISIONAL**: a safe, reversible default chosen by Claude Code. The user may override it.
- **OPEN**: not decided, and does not block the current milestone.
- **NEEDS USER DECISION**: Claude Code cannot settle it.

Owner of this file for technical entries: Claude Code. Claude Cowork reads it and does not edit solver assumptions.

---

## D-001 — Session-1 inputs, repository location and coordination (2026-10-29) — ACCEPTED (repository decided by the user, 2026-10-29)

**Files actually read in session 1**
- `PROJECT_SPEC.md`: an exact byte-for-byte copy of the uploaded `CE7405_Complete_Handoff_PROJECT_SPEC.md`, SHA-256 `df8833bd…5bfe`.
- `CE7405_Complete_Handoff.docx`, converted with pandoc. Its text matches the `.md` spec; only the equation formatting differs.

**Expected but not found in the session workspace**
- `START_HERE.md`
- `CE7405_Project_Proposal_Steel_RCC_Nov24_Matrix_Formatted.docx`
- `DECISIONS.md`, `VERIFICATION_LOG.md` and `CHANGELOG.md` (earlier versions)

None of these were invented. The record files here were started from scratch.

**Repository**
- The session working directory was empty and was not a git repository.
- The GitHub account has two private repositories, `JayashP/CE-7405` and `JayashP/CE7405-Project`. Attaching them to this cloud session was **denied**, so their contents were **not inspected**. Nothing in them was overwritten.
- A new local git repository was created at `/home/user/CE7405_Bridge_Platform`. It lives in an ephemeral cloud container with **no remote**, so it will be lost when the container is reclaimed unless it is pushed or downloaded.
- **Resolution (user decision, 2026-10-29):** `JayashP/CE-7405` is the project home repository.
  - When it was attached to the session with push access it was **completely empty**: no branches, no commits, no files.
  - Nothing needed merging and nothing was overwritten.
  - The M1 commit was pushed there as the first commit on `main`, which is the default branch.
- `JayashP/CE7405-Project` was **not** inspected and is not used by this project. If it holds earlier material, such as `START_HERE.md` or the proposal, that material still has to be reviewed by hand.
- The temporary local repository `/home/user/CE7405_Bridge_Platform` is superseded by the GitHub repository.

## D-002 — Internal units (2026-10-29) — ACCEPTED

All engine functions (`src/`) use SI units only:

| Quantity | Unit |
|---|---|
| length, coordinates, displacement | m |
| force | N |
| moment | N·m |
| rotation | rad |
| E | Pa |
| I | m⁴ |
| EI | N·m² |

There are no unit conversions inside `src/`. Tests and (later) the GUI convert only at the boundary. Current display units in tests: kN, kN·m, mm, rad. `model.units` records the labels.

## D-003 — Sign convention (2026-10-29) — ACCEPTED

Spec §4.3 and §16 asked for this to be decided once and recorded.

| Item | Convention |
|---|---|
| x | Along the bridge, origin at the left end (node 1), positive to the right |
| v (vertical displacement) | Positive **upward** |
| θ (rotation) | Positive **counterclockwise**, θ = dv/dx |
| Nodal force F_v | Positive **upward**. A downward gravity or axle load of magnitude P is entered as **−P** |
| Nodal couple M_z | Positive counterclockwise |
| Reactions | Force or couple exerted **on the beam by the support**. Same signs as above (up +, CCW +) |
| Element end actions `[F_i M_i F_j M_j]` | Forces and couples exerted **on the element by its end nodes**, in global DOF signs |
| Internal bending moment M(x) | Positive **sagging** (tension in the bottom fibre) |
| Internal shear V(x) | V(x) = sum of upward forces to the left of the section, so dM/dx = V. A downward point load makes V jump down by P |
| Element-end conversion | V_i = F_i, M(x_i⁺) = −M_i, V_j = −F_j, M(x_j⁻) = M_j |

Consequences verified by tests:
- A downward load gives negative v.
- Simple-span midspan moment is positive.
- The cantilever fixed-end moment is negative (hogging).
- θ_A < 0 and θ_B > 0 for a sagging simple span.

**Planned later (not implemented):** vehicle axle input will take positive-downward *magnitudes*, as in spec §5.1, and convert them to −P internally. The GUI may also show |δ| with explicit labels.

## D-004 — DOF numbering and element orientation (2026-10-29) — ACCEPTED

- Node n owns global DOFs `2n−1` (v) and `2n` (θ). The global vector is `[v1 θ1 v2 θ2 …]`.
- An element with nodes `[i j]` (i = left node) uses element DOFs `[v_i θ_i v_j θ_j]`, mapped to global `[2i−1 2i 2j−1 2j]` (`elementDofs`).
- Element length is `L_e = x_j − x_i > 0`.
- Elements are horizontal, so the local and global frames coincide (T = I).

## D-005 — Model data structure (2026-10-29) — PROVISIONAL

The model is a plain struct-of-arrays built by `createBeamModel(x, EI)`. Fields are listed in that function's help text.

- **Node coordinates are the primary geometry input.** `generateUniformMesh(L, ne)` produces a uniform mesh. A later span-based mesher for continuous beams only needs to output coordinates.
  - Supports and nodal loads are placed by node index.
  - `findNodeAtX` converts a coordinate to a node and **errors** (`BridgeFE:notOnNode`) instead of snapping to the nearest node.
- **One continuous beam only** (Option A). Connectivity must be `[(1:ne)' (2:ne+1)']`. There are no internal hinges and no overlapping elements.
- **EI is stored per element.** The solver sees only EI, so there is no separate steel or RCC solver path.
  - Steel uses EI = E_s·I_s. RCC uses EI = E_c·I_eff (user supplied).
  - Material labels, separate E and I inputs, and the steel/RCC equal-EI test are deferred to milestone M5 (`DEVELOPMENT_PLAN.md`).
- **The model struct stores inputs only.** Derived values (element lengths, K) are recomputed so they cannot go stale.
- **Supports:** `model.supports.{node, type, restraint}`, with at most one support per node.
- **Loads:** nodal loads as `model.loads.nodal = [node Fv Mz]` (M1). From M2 there is also a uniform load per element, `model.loads.elementUDL` (see D-015). Point loads inside elements arrive in M3.
- **Format version:** `model.meta.formatVersion` is 2 since M2 (added `loads.elementUDL`), 3 since M3 (added `loads.point`, see D-017) and 4 since M5 (added `materials` and `elements.materialId`, see D-022). Models are built in code, not stored, so there is no migration.

## D-006 — Supports and kinematic stability (2026-10-29) — ACCEPTED

**Support types**

| Type | Restrains v | Restrains θ |
|---|---|---|
| `'pin'` | yes | no |
| `'roller'` | yes | no |
| `'fixed'` | yes | yes |

Pin and roller are numerically identical in this bending-only model. Their horizontal difference needs axial DOFs, which this model does not have (spec §4.3). The GUI may still draw them with their conventional symbols.

**Stability rule** (`partitionDofs`)

A continuous chain of beam elements with EI > 0 has exactly two rigid-body modes:
- vertical translation: v = 1, θ = 0
- rigid rotation: v = x − x₀, θ = 1

The supports remove both modes if and only if:
- (a) v is restrained at two or more distinct nodes, or
- (b) v is restrained somewhere **and** θ is restrained somewhere.

Otherwise the code throws `BridgeFE:underRestrained`, naming the free mode. The test suite cross-checks this rule against `rank(Kff)` for 10 support layouts. The rule must be revisited if internal hinges or releases are ever added.

## D-007 — Solution method (2026-10-29) — ACCEPTED

- Partition into free and restrained DOFs. Restrained DOFs have **zero** prescribed displacement. Then solve `Kff·Uf = Ff` with backslash on sparse `Kff`.
- There is no `inv()`, no penalty method and no row/column zeroing.
- Prescribed nonzero support displacement (`Ff − Kfc·Uc`) is **not** implemented. It is OPEN.
- `rcond(full(Kff))` is computed for every solve and returned in `results.diagnostics.rcondKff`. Values below **1e‑12** issue the warning `BridgeFE:illConditioned`. This threshold is PROVISIONAL.
- For moving-load loops, a later milestone may factorize `Kff` once and reuse the factorization, because K does not change with vehicle position.

## D-008 — Reaction recovery (2026-10-29) — ACCEPTED

- Reactions are `R = (K·U − F)` evaluated at the restrained DOFs; R is zero elsewhere. This follows spec §4.2.
- A load applied directly at a restrained DOF therefore goes straight into the reaction. This is tested.
- Whole-structure equilibrium (ΣF_v and ΣM about x = 0, loads plus reactions) is returned in `results.diagnostics` and checked in the benchmarks.

## D-009 — Element force recovery (2026-10-29; updated for M2) — ACCEPTED

- Since M2, the element end actions are `f_e = k_e·q_e − f_e0`. Here f_e0 is the consistent load vector of the loads acting inside element e (`elementLoadVectors`); it is zero for unloaded elements. The end actions are converted to end shear and moment using D-003.
  - In M1 there were only nodal loads, so f_e0 was always zero.
- **Inside an element** with uniform load w (+ up), `sampleInternalForces` uses exact element equilibrium from the left-end values: V(s) = V_i + w·s and M(s) = M_i + V_i·s + w·s²/2. This gives the linear shear and parabolic moment of the real load, not just the end values.
- **Point loads inside elements (M3):**
  - Their f_e0 is the Hermite vector P·[N1 N2 N3 N4]ᵀ, included in `elementLoadVectors`.
  - `sampleInternalForces` adds the jump of size P to V(s) and the term P·(s − a) to M(s). Each load position is sampled twice, as the left limit then the right limit, so the jump is visible.
  - The end values V_j and M_j are the limits just left of node j (x_j⁻).
- **Deflection between nodes (M3):** `evaluateDeflection` adds the exact fixed-fixed particular solution of each in-element load (uniform or point) to the Hermite interpolation of the nodal DOFs. Hermite interpolation alone is not exact inside a loaded element.

## D-010 — Verification policy and tolerances (2026-10-29) — ACCEPTED

- **Fixed references.** Analytical references are closed-form expressions from spec §10, plus the literal spec values (50 kN, 500 kN·m, 8.333… mm). A test also checks the closed forms against those literal values. References are never edited to make a test pass.
- **Nonzero references:** percentage error with the spec target **< 0.1 %**. This applies to Benchmark A and the cantilever, including the full elastic curve normalized by δ_mid.
- **Zero references:** a percentage is undefined, so absolute error is used. The tolerance is **1e‑6 × the characteristic magnitude** of that quantity:
  - moments: 1e‑6·PL/4
  - forces: 1e‑6·P
  - rotations: 1e‑6·|θ_A|

  This choice is PROVISIONAL.
- **Exact algebraic identities** (element entries, symmetry, rank, null space): round-off tolerance of 1e‑12 relative (1e‑10 %), or exact equality where the arithmetic is exact.
- **Printed output.** Every comparison prints actual, expected, absolute error, percentage error, criterion and PASS/FAIL.
- **Test sensitivity.** `tools/mutation_check.py` injects 7 single faults. Each fault must make at least one test fail.

## D-011 — Test framework and runtime (2026-10-29) — PROVISIONAL

- **MATLAB is not installed** in the Claude Code container. App Designer and `matlab.unittest` are therefore unavailable. **No MATLAB result has been produced.** MATLAB status is **NOT RUN** until the user runs it locally.
- **GNU Octave 8.4.0** was installed (apt) and used to *execute the same `.m` source* as real evidence. Octave results are labelled as Octave, never as MATLAB.
- **Test format.** Tests are MATLAB **script-based unit tests**: a shared setup before the first `%%`, then one test per `%%` section. They therefore run unchanged in both environments:
  - MATLAB: `matlab.unittest`, via `runAllTests` or `runtests`.
  - Octave: `tests/helpers/runScriptTestsPortable.m`, which reproduces the same semantics (shared setup plus isolated sections).
- **Constraints for portable code** (MATLAB/Octave): no `arguments` blocks, `string` literals, tables or `contains`. Tests may not use local functions or `zz`-prefixed variable names.
- **Could change.** Once MATLAB is available, tests may switch to function-based `matlab.unittest` tests if richer diagnostics are wanted. The assertions themselves would not change.

## D-012 — Names and folder layout versus the spec's suggested layout (2026-10-29) — PROVISIONAL

- `src/solver/partitionDofs.m` does the job of the spec's suggested `applyBoundaryConditions.m`. It partitions DOFs and checks stability, and does not modify K.
- `src/loads/assembleNodalLoadVector.m` was added because only nodal loads exist in M1.
- `src/util/` holds three small input-validation helpers.
- `src/model/` also holds `addSupport`, `addNodalLoad`, `findNodeAtX`, `supportRestraint`, `elementDofs` and `generateUniformMesh`.
- No empty Stage 2/3/4, GUI or visualization files were created.
- M2 additions follow the spec's suggested names where one exists (`loads/equivalentDistributedLoad.m`).
- M5 adds the folder `src/materials/` (`defineMaterial`, `validateMaterial`, `assignMaterial`). The spec layout has no materials folder.
- M7 adds `src/damage/` (`applyStiffnessDamage`, `effectiveEI`, `relativeChange`, `compareHealthyDamaged`, `damageSensitivity`). This replaces the spec's suggested `damage/applyStiffnessDamage.m` alone.
- M6 adds these folders:
  - `src/gui/`: input parsing, model and vehicle builders, table data, theme.
  - `src/visualization/`: the drawing primitives and renderers. The spec suggested `plotBridge`; the drawing is now `bridgeDrawing` + `renderDrawing`, plus `plotDiagram` and `plotEnvelope`.
  - `app/BridgeConditionApp.m`: replaces the spec's `app/BridgeConditionApp.mlapp`, see D-023.
  - `tests/gui/`: the scripted app check, outside the main suite because it needs a display in MATLAB.
  - `tools/gui_mock/` and `tools/preview/`: development-only checks, see D-024.
  - `src/movingload/defaultEnvelopeStations.m` and `modelWithVehicle.m`.
- M4 keeps the spec name `loads/generateVehiclePositions.m`.
  - `vehicleLoadVector`, `calculateEnvelopes` and `findCriticalPositions` became parts of `src/movingload/`: `analyzeVehiclePosition` builds the load vector, and `runMovingLoad` computes the envelopes and critical positions.
  - `src/loads/` also holds `createVehicle`, `validateVehicle` and `vehicleAxlePositions`.
  - `src/movingload/` also holds `prepareMovingLoad` and `mapCoordinatesToElements`.
  - `src/loads/` also holds `elementLoadVectors` and `assembleLoadVector`.
  - `src/model/` also holds `meshSpans`, `elementsBetween` and `addUniformLoad`.
  - `src/postprocess/sampleInternalForces.m` covers V and M only, which is why it is not named `evaluateBeamResponse` (that spec name implies deflection too).
- Error identifiers use the `BridgeFE:` namespace, for example `BridgeFE:invalidInput`, `BridgeFE:invalidModel`, `BridgeFE:underRestrained`, `BridgeFE:duplicateSupport`, `BridgeFE:invalidSupportType` and `BridgeFE:notOnNode`.

## D-013 — Deadline (2026-10-29) — ACCEPTED

The final deadline is **24 November 2026**. It supersedes the 5 December date in the old course template (spec §12). The exact submission time is still to be confirmed with the instructor (OPEN).

## D-014 — Open items carried from spec §16 (2026-10-29) — OPEN

None of these block M1.

| Item | Current default / note |
|---|---|
| MATLAB release; App Designer and test runtime | Not available to Claude Code. User to state their local release |
| GUI workflow (one span field vs spans array, support coordinates, mesh auto-alignment) | Engine uses node coordinates plus `findNodeAtX` (errors if no node is there). Since M2, `meshSpans(spanLengths, elementsPerSpan)` gives exact nodes at every support, so a GUI can take a spans array |
| Variable EI and nonuniform mesh | Both are already supported by the data model and assembly (tested). Uniform EI is still the benchmark default |
| Uniform dead load as core or later | **Decided:** implemented in M2 as a consistent element load (D-015) |
| Vehicle reference axle and the policy for axles exactly at supports | **Decided** in M3 and M4 (D-017, D-019): the reference is the front axle; an axle at a node or support is applied at that node, so an axle on a support goes straight into the reaction; axles off the bridge are ignored by the moving-load analysis |
| Field deflection data format | No field data supplied. Stage 3 only |
| Stage 4 rule sources | Not selected. Stage 4 only |
| `.mlapp` packaging vs a runnable source GUI | **Decided by the user (2026-10-30):** code-built app `app/BridgeConditionApp.m` (D-023). It can still be packaged with MATLAB's Package App tool |

## D-015 — Uniformly distributed load (2026-10-29, M2) — ACCEPTED

- **Storage.** A uniform load is stored per element as an intensity w [N/m] in `model.loads.elementUDL` (NE-by-1, + up). A downward load of magnitude q is entered as **w = −q**, following D-003.
  - `addUniformLoad(model, w, elements)` superposes onto all elements, or onto the listed ones. `elementsBetween(model, x1, x2)` selects a span or a node-to-node range.
  - Partial-element loads are not supported. Loaded regions must start and end on nodes, the same rule as for supports and nodal loads (D-005).
- **Equivalent nodal load.** The consistent (work-equivalent) vector is f_e0 = w·[L_e/2, L_e²/12, L_e/2, −L_e²/12]ᵀ, the integral of w·N_i over the Hermite shape functions. A test checks it against Gauss integration.
  - It is assembled into F (`assembleLoadVector`) and subtracted in force recovery (D-009).
  - Because the Hermite functions are the exact homogeneous solutions, nodal displacements and end forces are exact for any mesh. Benchmark C even holds with one element.
- **Equilibrium diagnostic.** The global check in `solveStaticModel` uses the equivalent F. For a uniform load this F has the same resultant force and moment as the real load, so the check stays meaningful. This is tested on a nonuniform mesh.
- **Reactions.** Equivalent loads that land on restrained DOFs pass into the reactions through R = K·U − F (D-008).

## D-016 — Indeterminate benchmark set and tolerances (2026-10-29, M2) — PROVISIONAL

- **Benchmark C** (spec §10): propped cantilever with a uniform load. Target **< 0.5 %** (spec).
- **Benchmark D** (spec §10, listed as optional): two equal spans with a uniform load. The same 0.5 % target is used; the spec gives no separate target for D.
- **Supplementary indeterminate checks, target < 0.1 %:**
  - propped cantilever with a central point load
  - two spans with a point load at each midspan
  - two spans with only one span loaded (gives uplift at the far support)
  - unequal 10 m + 15 m spans checked by the three-moment equation
  - fixed-fixed beam with a uniform load, including the single-element case with no free DOFs
  - simple span with a uniform load
- **Field checks:** sampled M and V along each beam, and nodal v along each beam, are compared with the closed-form diagrams. Errors are normalized by a characteristic value: 5e‑3 for C and D, 1e‑3 elsewhere.
- **Zero references:** the 1e‑6 × characteristic-magnitude absolute rule (D-010) still applies.

## D-017 — Point loads at arbitrary positions (2026-10-29, M3) — ACCEPTED

- **Storage.** Point loads are stored by **global coordinate** in `model.loads.point = [x Fv]` [m, N], with Fv positive up (a downward axle load Q is entered as −Q). They are added with `addPointLoad`.
  - Each load is resolved to a node or an element only when loads are assembled (`locatePointLoads`).
  - A moving vehicle (M4) therefore only needs to replace this list for each position, without touching the mesh.
- **Load strictly inside an element.** The consistent vector f_e0 = P·[N1 N2 N3 N4]ᵀ is used, with r = a/L_e (spec §5.2). The load is **not snapped** to a node.
- **Load at a node.** A load within **1e‑9 × beam length** of a node is applied as a nodal force at that node.
  - At a node the Hermite vector equals a nodal force exactly (N3 = 1 at r = 1, N1 = 1 at r = 0), so this changes no result.
  - The tolerance only absorbs coordinate round-off. It also keeps element-end values unambiguous: V_j and M_j never include a load that sits on node j.
  - A load on a supported node goes straight into that reaction.
- **Off the beam.** A load more than 1e‑9 × beam length outside the beam throws `BridgeFE:offBeam`. Dropping axles that are off the bridge is the vehicle layer's job (M4).
- **Continuity.** Moving a load 1e‑7 m to either side of a node changes U by only 1.6e‑8 of its size (tested), so there is no discontinuity at element boundaries.

## D-018 — Benchmark B setup (2026-10-29, M3) — PROVISIONAL

- **Mesh.** Benchmark B (spec §10) uses a deliberately **coarse** mesh of 8 elements of 2.5 m on a 20 m span. Most load positions therefore fall inside elements.
- **Positions.** 88 positions are used: a 0.25 m grid (including every node and both supports), the odd positions 0.1, 1.234, 7.77, 12.3456 and 19.99 m, and 5 m ± 1e‑7 m.
- **Target.** < 0.5 % (spec) for the maximum relative error over positions of R_A, R_B, M under the load, v under the load and the size of the shear jump. Positions on a support are checked separately, with absolute tolerances.
- **Critical position.** The test checks that the largest moment under the load occurs at a = L/2. This is the basic critical-position check. Full envelopes and multi-axle critical positions are M4.

## D-019 — Vehicle definition, travel direction and position grid (2026-10-30, M4) — ACCEPTED

- **Vehicle.** `createVehicle(axleLoads, axleSpacings, name)` takes axle loads as positive-downward **magnitudes** [N], listed front to rear, and the spacings between consecutive axles [m]. The magnitudes become −P (D-003) only when applied.
  - The illustrative truck of spec §5.1 (80/120/120 kN, 4.2 m + 1.4 m) is used in tests. It is **not** an AASHTO design truck.
- **Reference axle and direction.** x_v is the coordinate of the **front axle**.
  - Toward +x (default), axle i is at x_v − (sum of spacings ahead of it).
  - Toward −x (`'Direction', -1`), the rear axles trail at x_v + offsets.
- **Crossing.** The crossing starts with the front axle at the bridge's first end and ends when the rear axle reaches the far end. At those two positions the only axle on the beam sits on an end support, so it only loads that reaction (D-017).
- **Grid.** The positions are equally spaced. The actual step is the largest value ≤ the requested step that divides the travel distance into whole steps, and it is reported as `ml.step`.
- **Axles off the bridge.** Axles beyond 1e‑9·L of the beam are ignored at each position (the vehicle layer filters them). Static `addPointLoad` still rejects off-beam loads.
- **Quasi-static only.** Each position is an independent static solution. No inertia, suspension, roughness, speed or impact effects are included (spec §5.1).

## D-020 — Fast moving-load solution (2026-10-30, M4) — ACCEPTED

- **Done once.** `prepareMovingLoad` assembles K, partitions the DOFs (with the stability check), factorizes **K_ff = R_cᵀ R_c once (Cholesky)**, and stores the element data and the permanent loads.
- **Done per position.** `analyzeVehiclePosition` adds the axle loads (nodal at nodes, Hermite vectors inside elements), solves with two triangular solves, and recovers f_e = k_e q_e − f_e0.
  - V and M come from exact element equilibrium, with both limits at every point.
  - v comes from Hermite interpolation plus the fixed-fixed particular solution.
  - These are the same formulas as the verified static functions, vectorized.
- **Speed.** About 2.8 ms per position in Octave, against about 72 ms per position through `solveStaticModel` + `sampleInternalForces` + `evaluateDeflection`.
- **Verification.** The fast path is checked against those verified M1–M3 functions at 14 positions in both directions, on a two-span model with unequal spans, two EI values and permanent loads. The largest normalized difference is 2.5e‑13 (D-010 round-off level).
- **Coincident points.** A load within 1e‑9·L of an evaluation point counts as at that point: the left limit excludes it and the right limit includes it. This keeps shear jumps robust to coordinate round-off.

## D-021 — Envelopes, critical positions and step refinement (2026-10-30, M4) — ACCEPTED

- **Stations.** The default stations are the nodes plus `StationsPerElement` (default 4) equal divisions of every element. Custom stations, such as sensor coordinates, can be passed.
- **Envelopes** (spec §5.3). At each station: max and min of M, of V (taking both limits, so jumps under axles and at supports are included), and of v. Each comes with the governing x_v. Reaction envelopes are kept per restrained DOF.
- **Envelope vs critical position.** The envelope at a station and the single vehicle position that governs a global extreme are reported separately (`ml.envelope` vs `ml.critical`). Each critical row records the quantity, max or min, value, x, x_v and the axle coordinates on the beam.
- **Critical search.** The global extremes are searched over the stations **and the points under every axle on the beam**, because the maximum moment under point loads occurs under an axle.
- **Step refinement** (`'Refine'`, default true). After the coarse sweep, positions within ±1 coarse step of every critical x_v and every reaction-extreme x_v are re-analysed at step/`RefineFactor` (default 10). Envelopes and critical values include these positions.
  - Each critical row keeps `coarseValue` and `coarseXv`, as evidence of convergence with the step.
  - For two axles, the coarse error obeys the bound (2P/L)(h/2)² from the quadratic shape of M near its optimum (tested).
- **Permanent loads.** Loads already in the model act at every position. Envelopes are therefore permanent plus live; superposition is tested. Use a model without loads for live-load-only envelopes.
- **Not included:** load factors, dynamic allowance, lane or multiple-presence factors, and code load models. Results are analysis outputs, not a load rating (spec §1).

## D-022 — Steel and RCC material input (2026-10-30, M5) — ACCEPTED

- **One solver.** Materials only record where EI comes from; the solver uses EI alone (spec §4.4). There is no steel or RCC branch anywhere in the solver.
  - `defineMaterial('steel', Es, Is)` gives EI = E_s·I_s.
  - `defineMaterial('rcc', Ec, Ieff)` gives EI = E_c·I_eff.
- **RCC.** I_eff is **supplied by the user or justified elsewhere** for the assumed cracking state, and stays **constant** during the linear analysis.
  - The tool does not compute I_eff from reinforcement.
  - It does not model cracking, yielding, creep, shrinkage, slip or any change in stiffness under load.
  - The optional `basis` text records where E and I_eff came from, for traceability.
- **Assignment.** `createBeamModel(x, material)` applies one material to every element. `assignMaterial(model, material, elements)` applies it to selected elements, so spans can differ (e.g. a steel span next to an RCC span).
  - Identical material records are stored once in `model.materials`. `model.elements.materialId` points to them, with 0 meaning EI was given directly as a number.
- **Consistency guard.** `validateModel` rejects an element whose EI no longer equals E·I of its material. Material input therefore cannot silently disagree with the EI actually analysed.
  - Stage 2 (M7) will add EI loss as a **separate** factor (EI_D = (1 − d)·EI from the material), keeping the material record intact.
- **Unit-sanity warning.** `BridgeFE:unusualModulus` is issued (as a warning, not an error) when E is outside 150–250 GPa for steel or 10–70 GPa for RCC. It catches GPa/MPa/Pa slips. The ranges are broad plausibility bounds, not engineering limits.
- **Equal-EI equivalence** (spec §4.4) is tested. A steel model and an RCC model with the same assigned EI give bit-identical static results and identical moving-load envelopes. This checks input and solver consistency only. It is not evidence about real concrete behaviour.

## D-023 — GUI format and architecture (2026-10-30, M6) — ACCEPTED (format chosen by the user)

- **Format.** The user chose a **code-built MATLAB app**, `app/BridgeConditionApp.m`, over an `.mlapp` file and over the "code now, `.mlapp` later" option, after a written comparison of the three.
  - It uses the same components App Designer generates (`uifigure`, `uigridlayout`, `uitab`, `uiaxes`, `uitable`, ...), written as text.
  - It is diffable and reviewable in git. It cannot be edited in App Designer's Design View.
  - Launch it with `addProjectPaths; app = BridgeConditionApp;`.
- **No calculations in the app** (spec §11). The app only:
  - calls `buildModelFromInputs`, `vehicleFromInputs`, `prepareMovingLoad`, `analyzeVehiclePosition`, `runMovingLoad`, `modelWithVehicle` + `solveStaticModel`, and `runAllTests`;
  - draws what `bridgeDrawing` and `responseDiagramData` return;
  - fills tables from `currentReactionTableData`, `criticalTableData`, `reactionEnvelopeTableData`, `formatMatrixCells` and `dofLabels`.

  All of these are tested in the main suite.
- **Tabs** (spec §5.4, §9):
  1. **Bridge model**: spans, elements per span, supports at span ends (pin, roller, fixed or none), steel or RCC with E [GPa] and I_s/I_eff [m⁴] plus name and basis, permanent uniform load [kN/m, downward], node and element numbers.
  2. **Vehicle & moving load**: axle loads [kN] and spacings [m], position step, travel direction, deformation scale (0 = automatic), a position slider with Start/Back/Forward, the truck schematic and dashed deformed shape, M, V and v diagrams, and reactions at that position.
  3. **Envelopes**: runs `runMovingLoad`; plots M, V and v envelopes with critical points; shows the critical-position and reaction-envelope tables.
  4. **Matrices**: k_e of a chosen element, global K, and a table of each DOF with free/restrained status, F, U and R at the current vehicle position (computational transparency, spec §1).
  5. **Verification**: runs `runAllTests` and shows its output.
- **Display units.** The app shows m, kN, kN·m, kN/m, GPa and mm. Conversions happen only in `src/gui` helpers (D-002). Labels state the signs: loads downward-positive as magnitudes, M + sagging, v + up.
- **Drawings** (spec §9): conventional symbols only.
  - pin: triangle on a hatched ground line
  - roller: triangle on two wheels on a hatched ground line
  - fixed: wall hatched outside the beam
  - loads: arrows with values
  - vehicle: axles on the bridge in blue, axles off the bridge dotted grey, with a truck body and cab on the leading side
  - deformed shape: dashed, with its magnification stated

  Theme: `appTheme` (sage green).
- **Bad input is handled, not crashed on.** The app shows `uialert` with the engine's message and records `app.LastError`, and the previous model is kept. Unit-slip warnings from `defineMaterial` are shown as a warning alert.

## D-024 — How the GUI is verified without MATLAB (2026-10-30, M6) — PROVISIONAL

- **Constraint.** Claude Code has no MATLAB. GNU Octave 8.4 here has no App Designer components, and its plot rendering fails in this container (FreeType error with every toolkit tried), so no window or figure can be produced here.
- **Layer 1, in the main suite (MATLAB and Octave).** `testGuiHelpers` and `testDrawingGeometry` cover:
  - input parsing
  - model and vehicle building, compared with direct engine construction
  - table contents
  - diagram data
  - the support-symbol geometry: pin apex, roller wheels on the ground line, fixed hatching outside the beam
  - load arrows, vehicle axles and the deformed shape
  - axis limits with room for labels
- **Layer 2, the scripted app check `tests/gui/checkBridgeConditionApp.m`.** It drives the app through its public methods and controls, like a user, and checks it against direct engine calls. It also invokes every button, value and tab callback.
  - The same file runs in **MATLAB on the real app (user)** and in **Octave against stand-in components** (`tools/gui_mock`, `runGuiMockCheck`).
  - The stand-ins list the real components' properties, so unknown property names, Layout set outside a grid, invalid colours, out-of-range values and malformed plot/legend calls are errors.
  - The Octave run shows that the code runs and is wired correctly. It **cannot** show MATLAB's actual rendering or layout.
- **Layer 3, drawing previews.** `tools/preview` exports the drawing primitives and diagram data to JSON and renders them with matplotlib, so the geometry the app will draw can be inspected as PNG. These are not MATLAB screenshots.
- **The final GUI evidence is the user's MATLAB run.** That means `runAllTests`, then `checkBridgeConditionApp(true)`, then opening the app and sending screenshots of each tab. Until then, GUI rendering is **NOT VERIFIED IN MATLAB**.

## D-025 — Stage 2 stiffness-loss model and comparison rules (2026-11-05, M7) — ACCEPTED

- **Damage model** (spec §6). A prescribed loss d (0 ≤ d < 1) is stored per element as `model.elements.stiffnessFactor = 1 − d`, set by `applyStiffnessDamage(model, elements, d)`.
  - The analysed rigidity is `effectiveEI(model) = EI .* stiffnessFactor`, so EI_D = (1 − d)·EI.
  - The material EI (E·I) and the material record are **never changed**. The D-022 consistency guard stays valid, and d = 0 restores a bit-identical healthy model.
  - Setting d replaces the earlier loss of those elements; the losses do not compound.
  - `model.meta.formatVersion` changes from 4 to 5.
- **One EI for every calculation.** All engine functions that compute with EI use `effectiveEI`: `assembleGlobalK`, `recoverElementForces`, `evaluateDeflection`, `prepareMovingLoad` (fast path, including the in-element deflection term), and the app's Matrices tab.
- **Comparison** (`compareHealthyDamaged`). This runs `runMovingLoad` on both models with the same vehicle and options. It reports:
  - envelope changes at every station;
  - for each global extreme, the healthy and damaged values with the governing x_v of each (these can differ);
  - the reaction maxima and minima.
- **Percentages** (`relativeChange`): 100·(D − H)/|H|, signed, as in spec §6.
  - Where the healthy value is zero (≤ 1e‑9 × the quantity's scale), the percentage is NaN and the absolute change is used.
  - For negative quantities (downward deflection, hogging moment), a negative percentage means a **larger magnitude**.
- **Sensitivity** (`damageSensitivity`). The same d is moved over element groups (default: each element in turn) and one global quantity is ranked by |change|. Supported quantities: Mmax, Mmin, Vmax, Vmin, vmax, vmin, and Rmax/Rmin at a chosen node. This is a forward-model sensitivity, **not** damage identification (Stage 3).
- **Interpretation** (spec §§4.4, 14). d is a loss of model flexural rigidity in an equivalent-beam segment. It is **not** a percentage of corrosion, section loss or capacity, and the segment is a model region, not an identified girder.
- **Tested behaviour:**
  - A statically determinate span keeps its reactions and moments (only deflection changes).
  - Indeterminate beams redistribute, matching closed-form compatibility and three-moment results.
- **Not yet in the GUI.** A Damage tab (choose elements and d, then show healthy vs damaged) is a possible follow-up (M7b).

## D-026 — Damage tab in the app (2026-11-10, M7b) — ACCEPTED

- **Scope.** A sixth tab, "Damage (Stage 2)", placed before Matrices. It only calls the verified Stage 2 engine (D-025); it adds no new mechanics.
- **Input.** One damaged region per application: "from x" and "to x" in m, which must be node coordinates (`elementsBetween`; an off-node value is rejected with `BridgeFE:notOnNode`), and a loss d in % with 0 ≤ d < 100 (`damageModelFromInputs`).
  - Applying a new region replaces the earlier damage; regions are not combined in the app (the engine can combine them).
  - The damaged model is kept separately in `app.DamagedModel`. `app.Model` stays healthy, so the Model, Vehicle, Envelopes and Matrices tabs always show the healthy bridge.
  - Changing the model clears the damage; changing the vehicle clears only the damage results.
- **Outputs.**
  - Drawing: the damaged run is overdrawn thick in a plum colour (`appTheme().damage`), one line per run of equal factors, labelled `EI x 0.70`.
  - "Compare healthy vs damaged" runs `compareHealthyDamaged` with the app's vehicle, step and direction. Moment and deflection envelopes are overlaid (healthy dashed, damaged solid). The table lists the six extremes and the maximum/minimum vertical reaction of every support, with the signed % of D-025 ("n/a (healthy = 0)" where the healthy value is zero).
  - "Run sensitivity" moves the same d over every element (`damageSensitivity`, `'Refine', false`, step = max(app step, sweep step), default 0.5 m, to keep the sweep fast) for one chosen response, with a bar chart and a ranking table.
- **Wording.** The tab states that d reduces model flexural rigidity and is not a percentage of corrosion, section loss or capacity (spec §§4.4, 14).
- **Verification.** Helpers tested as data in Octave/MATLAB tests; the app wiring by 6 new rows of `checkBridgeConditionApp` (32 rows). The rendering itself needs the user's MATLAB screenshot.

## D-027 — Damage-tab display revisions after the first MATLAB screenshots (2026-11-10, M7c) — ACCEPTED

Problems seen in V-016 and the changes made. No engine code and no reference value changed.

| Seen in MATLAB | Change |
|---|---|
| On a simple span the healthy moment curve vanished under the identical damaged curve, so it looked as if the healthy result was missing | `plotEnvelopeComparison` draws the damaged envelope first (thick, plum) and the healthy one **on top** (thin, dashed, dark grey), so coinciding curves stay visible |
| The user asked why healthy and damaged forces are equal | A **Findings** box (`damageComparisonSummary`) states whether the beam is statically determinate (restrained DOFs = 2: forces cannot change with EI) or indeterminate (degree = restrained DOFs − 2: forces redistribute), the largest % change of an extreme and whether its magnitude grew, and the largest reaction change |
| Round-off printed as `−0.000` and `−0.00 %` | `formatNumber` rounds for display and never prints a negative zero; zero changes have no sign. Stored results are unchanged |
| Titles cut off in the normal window; sensitivity chart and table squeezed into a corner; `1 2 3 4 5 6` headings before the first run | Results moved into two sub-tabs, "Healthy vs damaged" (M, V and v envelopes, table, findings) and "Sensitivity along the beam" (bar chart and ranking table side by side). Short titles; column headings and "press …" hints from the start; the sub-tab switches to the result just computed |
| `EI x 0.70` label small | Font size 11 |
| Single-element groups shown as `8-8` | Shown as `8` |

## D-028 — Stage 3 single-region inverse search (2026-11-10, S3) — ACCEPTED

Engine only (`src/inverse/`); an app tab is a later step. PROJECT_SPEC.md §7.

- **Observations.** `uObs(i, p)` is the deflection [m, + up] at sensor `sensorX(i)` with the vehicle's front axle at `xvList(p)`. It is the deflection caused by the **vehicle only**, measured from the unloaded bridge. `predictSensorDeflections` therefore subtracts the response to any permanent loads (vehicle placed off the beam). Missing readings are `NaN` and are left out of J.
- **Forward model.** This is the verified moving-load fast path (`prepareMovingLoad` with the sensors as stations, then `analyzeVehiclePosition`). It gives exact Euler–Bernoulli deflections at sensors between nodes (Hermite interpolation plus the fixed–fixed particular solution) and uses the effective EI = (1 − d)·EI.
- **Candidates.**
  - The healthy model is evaluated once.
  - The coarse scan covers every group (default: each element) at d = 5 %, 10 %, …, 60 %. For 20 elements that is 240 + 1 = 241 structures.
  - The 3 best groups are refined in 1 % steps within ±5 % of their coarse optimum, never above 60 %.
  - Groups can be element ranges (`'Groups'`), e.g. 2 m regions.
- **Objective.** J = RMSE = sqrt(mean((u_FE − u_obs)²)) over the m observed values; J_N = sqrt(Σr²/Σu_obs²) is also reported.
- **Best candidate.** The candidate with minimum J. The healthy model wins ties, so no damage is reported without evidence.
- **Competing candidates and region of uncertainty.**
  - Every group whose best J is within `AmbiguityRatio` × J_best (default 1.10) competes. A J below 1e‑9·RMS(u_obs) counts as an exact fit, with ratio 1.
  - The competing groups' x-ranges are merged into one or more regions of uncertainty. `dRange` is the range of d of the best group within the ratio.
  - `healthyCompetes` is set when the healthy model is itself within the ratio.
  - These are **fit-ratio sets, not calibrated confidence sets or probabilities** (spec §7).
- **Search limit.** A best d at 60 % sets `boundaryFlag`. A larger true loss cannot be represented, and the location found is then not reliable (test: true E7 at 70 % gives E9 at 60 %, flagged).
- **Optional noise check.** With a stated noise standard deviation σ (`'NoiseRMS'`), the healthy model is called consistent with the data if m·J0²/σ² ≤ m + 1.645·sqrt(2m). This is an approximate one-sided 95 % χ² test, assuming independent Gaussian noise of that size.
- **Synthetic noise** (`addMeasurementNoise`):
  - By default it is proportional to each reading, u(1 + level·z), the usual definition in damage-identification studies. Option `'rms'` gives one absolute σ = level × RMS(u).
  - z comes from `deterministicNormal`, a documented LCG with Box–Muller, so a noisy case is **identical in MATLAB and Octave**; `rng` and `randn` streams differ between the two.
- **Scope** (spec §§4.4, 7, 8): one degraded region; no physical mechanism (corrosion, cracking, …) is inferred. RCC inverse use is deferred, because cracking and an uncertain baseline I_eff can mimic damage. Agreement with self-generated data is **algorithm verification, not field validation**. No field data have been supplied.

## D-029 — Stage 3: noise-based region of uncertainty, fit check, candidate region size (2026-11-11, S3b) — ACCEPTED (user chose options 3 + 2)

**Why.** In the V-018 noise study the D-028 "RMSE within 10 % of the best" region often missed the true damage. A region that looks precise but misses is what spec §7 warns against. The user compared three remedies on measured numbers and chose option 3 (a noise-based region) plus option 2 (selectable candidate region size). An independent multi-agent review (four reviewers, each serious finding checked by a skeptic) then changed several details, listed under "Review changes".

- **Two methods, chosen by the input.**
  - Without a stated noise level: `'ratio'`, unchanged from D-028.
  - With `'NoiseLevel'` (a fraction of each reading) and/or `'NoiseAbsolute'` (a standard deviation in m): `'likelihood'`.
- **Noise per reading:** σ_i = sqrt((NoiseLevel·|u_healthy,i|)² + NoiseAbsolute²), using the **healthy model's prediction**, never the observed readings.
  - Weights from observed readings favour readings that noise happened to make smaller. That biases d low and inflates S (review finding).
  - A reading whose σ_i = 0 (e.g. the truck off the span with only a proportional level) is rejected with a request for an absolute part.
- **Best candidate.** It minimizes S = Σ(r_i/σ_i)² (weighted least squares).
  - With one constant σ this is the same candidate as the spec's minimum RMSE (tested: S = m·J²/σ² for every structure).
  - J (RMSE) and J_N are still computed and reported for every candidate (spec §7).
- **Refinement.** With a stated noise level, **every** group is refined in 1 % steps within ±5 % of its coarse optimum, so region membership is never decided on the 5 % grid.
  - About 400–440 structures instead of 265 for 20 elements, including the vertex structures.
  - Tested: the same region and best fit as an exhaustive 1 % scan (1200 structures).
- **Minimum between grid points.**
  - For each group, **one more structure is analysed** at the vertex of the parabola through its lowest 1 % point and the two neighbours; the healthy value serves as the d = 0 neighbour. The vertex is used only when it lies strictly between the neighbours, never at d ≤ 0.
  - Every S used for the best candidate, the region and the fit check is therefore a computed value, not an estimate (skeptic's refinement of the review fix). A loss between grid points with a small stated noise is not mistaken for a misfit.
  - Tested: E7 at 27.4 % with 0.1 % stated noise gives S = 4.73 at the best 1 % point, and S = 0.0016 at the vertex d = 0.2739.
- **Region of uncertainty.**
  - Every group with S_min − S_min,best ≤ χ²(Confidence, 2), which is 5.99 for 95 %. This is the likelihood-ratio region for the two unknowns, location and loss. It is reported as merged x-ranges plus each group's d range on the 1 % grid.
  - It is **approximate**: location is discrete, u is nonlinear in d, and d = 0 is a boundary. Its coverage is therefore **measured** (tools/inverseNoiseStudy, VERIFICATION_LOG), never asserted, and it is not a probability that a region is damaged.
- **Healthy model.** If the healthy model is inside the region, `healthyCompetes` is set: "no damage" cannot be ruled out.
- **Fit check.**
  - If S_min,best > χ²(Confidence, dof), no candidate explains the data within the stated noise and `modelMisfit` is set.
  - dof = m − 2, or m when the healthy model (no fitted unknowns) fits best.
  - Causes: noise underestimated; wrong supports, loads or baseline EI; more than one damaged region.
  - Tested: data from a fixed–roller beam analysed as pin–roller is flagged; with the correct supports it is not.
- **χ² quantiles.** `chiSquareQuantile`: bisection on `gammainc` (core MATLAB and Octave; no Statistics Toolbox), for K ≥ 1, checked against table values.
- **Candidate region size (option 2).** `candidateGroups(model, length)` gives contiguous element groups of about `length` metres, ending on nodes; a short last group of less than half the length is joined to the previous one. The groups are passed through `'Groups'`.
  - Larger regions are more robust with few sensors.
  - But the location is coarser, and d is spread over the region: a 30 % loss over 1 m looks like a smaller loss over 2 m.
- **Synthetic noise generator (review finding).** `deterministicNormal` used the seed directly as the LCG state, so consecutive seeds gave almost the same first numbers: the first value for seeds 1–6 was −1.16, −1.64, −1.61, −1.07, −0.19, 0.75.
  - Coverage measured over seeds 1..N was therefore **not** over independent noise draws, so the V-018 study and the first coverage numbers shown to the user on 2026-11-10 are **superseded**.
  - The seed is now scrambled with the lowbias32 integer hash (`hashSeed32`, exact in doubles, checked against an independent Python implementation). Over seeds 1–2000 the first value now has mean 0.014, std 0.999 and correlation between neighbouring seeds of −0.007.
- **Review changes**, in order of importance:
  1. refine every group, instead of a fixed margin of 2 that failed at small σ;
  2. σ from the healthy prediction;
  3. seed hash;
  4. a structure at each group's parabola vertex, so the minimum between grid points is computed;
  5. removal of `healthyConsistentWithNoise`, an omnibus test that contradicted the region;
  6. dof = m when the healthy model fits best;
  7. scalar `'Levels'` no longer crashes;
  8. `chiSquareQuantile` restricted to K ≥ 1;
  9. `regionAtSearchLimit`: the region's d range reaching the 60 % limit is flagged even when the best d is below it;
  10. one consistent best (the smallest computed S), which is also the anchor of the region and of the fit check;
  11. `minRMSE` (spec §7's minimum-RMSE candidate) is reported alongside;
  12. an RCC baseline gives warning `BridgeFE:rccInverse` and `rccBaseline = true` (spec §7 defers RCC).

  The tests added for documented behaviour cover: σ with both parts, a 90 % confidence level, missing readings in likelihood mode, the p-value, small stated noise, the exhaustive 1 % comparison, and the healthy-best dof.

## D-030 — Identification tab (Stage 3) in the app (2026-11-12, M8) — ACCEPTED

- **Scope.** A seventh tab, "Identification (Stage 3)", placed before Matrices. It calls only the verified Stage 3 engine (D-028, D-029) through tested helpers in `src/gui` and `src/visualization`. There is no new mechanics.
- **Inputs.**
  - Sensors and truck front-axle positions are typed as number lists.
  - Defaults (`identificationDefaults`): sensors at L/4, L/2 and 3L/4. Positions at L/4, L/2, 3L/4, L and 5L/4 from the entry end, so mirrored for travel toward −x. Positions at which no axle is on the beam are dropped, because they would give zero readings. For the spec's 20 m span and 3-axle truck this is exactly spec §7: sensors at 5, 10, 15 m; positions 5, 10, 15, 20, 25 m.
  - The vehicle and travel direction come from the Vehicle tab. A model or vehicle change resets the defaults and clears the readings.
- **Readings.**
  - **Synthetic test case:** a hidden region on node coordinates, a loss d in %, proportional noise in % and a seed (`syntheticObservations`). The hidden case is stored apart (`IdentTruth`); the search never receives it. It is shown on the drawing and in the summary only after the search.
  - **Measured readings:** "New empty table" gives an editable table in mm (downward negative); an empty cell means missing.
  - Editing any cell drops the synthetic truth, because it no longer describes the readings.
  - A run is refused when the sensors or positions differ from those the table was made for.
- **Search.**
  - Stated reading noise: % of each reading and/or mm. Both 0 gives the D-028 ratio method, and the text says it is not a confidence region.
  - Candidate regions: each element, 2 m or 4 m (`candidateGroups`, D-029 option 2).
- **Outputs.**
  - Drawing: sensors S1…; the region of uncertainty as a light band behind the beam; the best fit as a thick line with its loss; the hidden case as a dashed box.
  - "Readings [mm]" sub-tab: the table, and a plot of readings (markers), the healthy model (dotted) and the best fit (solid) against truck position.
  - "Fit by location" sub-tab: one bar per candidate region (S − S_best, or RMSE / best RMSE), amber inside the region; the limit dashed; "no damage" dotted. Bars above four times the limit are cut off and marked with a triangle.
  - A candidates table, which includes "no damage" when it is inside the region.
  - A plain-language summary: method, best fit, region, every limiting flag (failed fit check, healthy model competing, search limit, RCC), the comparison with the hidden case, and the caveats (synthetic data = algorithm check; the cause is not identified; fit measures are not probabilities).
- **Display fixes from V-020.**
  - `legend(ax, 'off')` after `cla`, so no empty legend boxes remain.
  - No duplicate row numbers in the Damage tables.
  - Node coordinates are shown with `%.6g` (13.875, not 13.88).
  - Shorter plot titles.
  - The best-fit label sits below the beam, where permanent-load arrows cannot cover it (found in a matplotlib preview).
- **Independent review (12 agents: 3 reviewers — MATLAB UI, semantics, tests — plus a skeptic for each serious finding).** Confirmed and fixed:
  1. **Hidden graphics handles (high; also a latent M6/M7b bug).** `cla(ax)` deletes only objects with visible handles. The plots used `HandleVisibility 'off'` to keep objects out of legends: envelope band, zero line and critical markers since M6; the comparison zero line since M7b; the Stage 3 sensor curves, labels and cut-off markers. In MATLAB and in real Octave graphics, such objects stay after `cla`: stale curves and labels remain visible and still set the axis scale. The skeptic reproduced this with Octave graphics.
     - Now no plot uses hidden handles. Legends are built from explicit handles, `legend(ax, [h1 h2], labels)`.
     - The Octave stand-ins return numeric handles, so they can check that form; the old stand-in `cla` wiped everything, which hid the bug.
  2. **TeX label.** `'S - S_best'` would render as S − S_b est; it is now `'S - S_{best}'`.
  3. **Fit chart layout.** The title overflowed the narrow chart. The chart now sits above the candidate table at full width, with the key moved into a legend.
  4. **Crowded annotations.** Labels under the beam were 0.25h apart. Now: best fit at −0.45h, hidden case at −1.0h, sensors at −1.65h. No node numbers on this drawing.
  5. **"No damage" best fit.** It hid the region where damage cannot be ruled out. It is now reported, and "no damage" is the first table row.
  6. **Zero readings.** Default sensors or positions could give all-zero readings (an axle only on a support, or a sensor on a support), which the noise-based search rejects. They are dropped by checking the healthy prediction: on a 10 + 10 m bridge the sensor at L/2 is left out.
  7. **Tests.**
     - Exact object counts for the drawing and both plots, plus their legends.
     - The ratio branch of the profile.
     - The RCC, search-limit and "no damage" summary lines.
     - A −x travel run through the tab.
     - A tautological assertion was removed.
- **Also fixed** (low findings):
  - the summary names how the best fit is ranked, and shows the spec's minimum-RMSE candidate when it differs;
  - the hidden case is compared by "best-fit region contains the true region", so 2 m and 4 m candidates work, with a note that the loss is then spread;
  - an edited readings table updates the text and plot;
  - the readings table headers are cleared on reset;
  - "NaN = missing" wording;
  - the S labels sit at the right-most position for −x travel.
- **Found by the app check while fixing:** applying a vehicle also reset the user's hidden-case inputs. Now a vehicle change resets only the truck positions (which depend on it) and the readings.
- **Addendum after the first MATLAB screenshots of the tab (2026-11-14):**
  - the best fit is marked with a star in the fit chart, because its bar has zero height;
  - the readings legend names the sensors by colour and marker, and the line styles are explained in a two-line title;
  - the readings table auto-fits its columns;
  - the full summary has its own "Summary" sub-tab;
  - the left box shows the best fit and every limiting flag.

  A side-by-side summary next to the table was rejected after review: at the default window size it would have been about 156 px wide.

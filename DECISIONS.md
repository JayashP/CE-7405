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
- **Format version:** `model.meta.formatVersion` is 2 since M2 (added `loads.elementUDL`) and 3 since M3 (added `loads.point`, see D-017). Models are built in code, not stored, so there is no migration.

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
| Vehicle reference axle and the policy for axles exactly at supports | Partly decided in M3 (D-017): a load exactly at a node or support is applied at that node, so a load on a support goes straight into the reaction; loads off the beam are rejected (`BridgeFE:offBeam`). The vehicle reference axle and the rule for skipping axles off the bridge are still open (M4) |
| Field deflection data format | No field data supplied. Stage 3 only |
| Stage 4 rule sources | Not selected. Stage 4 only |
| `.mlapp` packaging vs a runnable source GUI | Not decided. Needed in M6 |

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

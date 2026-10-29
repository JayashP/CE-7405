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

## D-001 — Session-1 inputs, repository location and coordination (2026-10-29) — NEEDS USER DECISION

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
- **User decision needed:**
  1. Which GitHub repository is the project home.
  2. Whether to push or merge this milestone there.
  3. Whether any `START_HERE.md`, `DECISIONS.md` or similar files in that repository must be reconciled with these.

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
- **Loads:** only nodal loads exist in M1, as `model.loads.nodal = [node Fv Mz]`. In-element loads arrive in M2/M3.

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

## D-009 — Element force recovery (2026-10-29) — ACCEPTED, with an M1 limitation

- `f_e = k_e·q_e` gives the element end actions. These are converted to end shear and moment using D-003.
- **Limitation:** this is complete only because M1 has nodal loads only.
- When in-element loads are added (M2 for UDL, M3 for Hermite point loads), recovery **must** become `f_e = k_e·q_e − f_e0`. Here f_e0 is the consistent load vector of the member loads.
- The interior V(x) and M(x) must also include the real in-element loads: shear jumps under point loads and the correct piecewise or parabolic moment (spec §5.2).
- This limitation is stated in the help text of `recoverElementForces`.

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
- Error identifiers use the `BridgeFE:` namespace, for example `BridgeFE:invalidInput`, `BridgeFE:invalidModel`, `BridgeFE:underRestrained`, `BridgeFE:duplicateSupport`, `BridgeFE:invalidSupportType` and `BridgeFE:notOnNode`.

## D-013 — Deadline (2026-10-29) — ACCEPTED

The final deadline is **24 November 2026**. It supersedes the 5 December date in the old course template (spec §12). The exact submission time is still to be confirmed with the instructor (OPEN).

## D-014 — Open items carried from spec §16 (2026-10-29) — OPEN

None of these block M1.

| Item | Current default / note |
|---|---|
| MATLAB release; App Designer and test runtime | Not available to Claude Code. User to state their local release |
| GUI workflow (one span field vs spans array, support coordinates, mesh auto-alignment) | Engine uses node coordinates plus `findNodeAtX` (errors if no node is there). A span-based mesher that aligns nodes with supports comes in M2 |
| Variable EI and nonuniform mesh | Both are already supported by the data model and assembly (tested). Uniform EI is still the benchmark default |
| Uniform dead load as core or later | Needed for Benchmarks C and D. Planned for M2 as a consistent element load |
| Vehicle reference axle and the policy for axles exactly at supports | Not decided. Needed in M3/M4 |
| Field deflection data format | No field data supplied. Stage 3 only |
| Stage 4 rule sources | Not selected. Stage 4 only |
| `.mlapp` packaging vs a runnable source GUI | Not decided. Needed in M6 |

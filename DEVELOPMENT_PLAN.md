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
| M1 | Element, assembly, supports, static solve, reactions, nodal-load force recovery, Benchmark A | Oct 28 – Nov 1 | **Done in GNU Octave 8.4.0 (26/26 tests). MATLAB run NOT RUN, pending the user** |
| M2 | Indeterminate beams: span mesher, propped cantilever, two-span continuous, UDL, Benchmarks C and D | Nov 2 – 7 | Next |
| M3 | Point loads anywhere inside elements (Hermite), interior V/M/deflection recovery, Benchmark B | Nov 8 – 10 | Not started |
| M4 | Multi-axle vehicle, position stepping, envelopes, critical positions, step refinement | Nov 10 – 13 | Not started |
| M5 | Steel / RCC input layer (E_s·I_s, E_c·I_eff) and equal-EI equivalence test | Nov 14 – 15 | Not started |
| M6 | Basic App Designer GUI over the verified engine (sage green, conventional supports, matrix inspection) | Nov 13 – 17 | Not started; needs MATLAB |
| M7 | Stage 2: prescribed EI loss, healthy vs degraded comparison, redistribution on an indeterminate beam | Nov 18 – 20 | Not started |
| S3 | Stage 3 inverse search (stretch) | Nov 21 – 23, only if M1–M7 are verified | Deferred |
| S4 | Stage 4 steel repair categories from sourced rules (stretch, last) | Only if time remains and sources are chosen | Deferred |
| — | Stabilize, demo recording, final documentation | Nov 21 – 23 | — |
| — | **Submission** | **Nov 24** | — |

## M1 — done (Octave evidence), MATLAB confirmation pending

**Delivered**
- `beamElementStiffness`, `elementDofs`, `assembleGlobalK`
- `createBeamModel`, `generateUniformMesh`, `addSupport`, `supportRestraint`, `addNodalLoad`, `findNodeAtX`, `validateModel`
- `assembleNodalLoadVector`
- `partitionDofs` (with an exact under-restraint check), `solveStaticModel`, `recoverReactions`, `recoverElementForces`
- 26 script-based tests, the runner, and the mutation check

**Open action for the user:** run `matlab -batch "runAllTests"` locally. Then record a V-002 entry in `VERIFICATION_LOG.md`.

## M2 — indeterminate beams (next gate)

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

## M3 — point loads inside elements (Benchmark B)

- Add `beamShapeFunctions` (Hermite N1–N4 with r = a/L_e) and `equivalentPointLoad`, f_e0 = P·[N1 N2 N3 N4]ᵀ. Loads are **not snapped** to nodes.
- Recover V and M inside loaded elements from element equilibrium, using the end actions plus the real point loads. Shear must jump by P at the load, and M must be piecewise linear.
- **Technical note:** inside a loaded element, interpolating the nodal DOFs with Hermite functions is *not* the exact deflection. The fixed–fixed particular solution of the in-element load must be added. This matters later for sensor deflections in Stage 3.
- **Benchmark B:** a single load at many positions on a simple span, including positions inside elements, exactly at element boundaries and at supports.
  - R_A = P(L−a)/L, R_B = Pa/L, M(a) = Pa(L−a)/L.
  - The maximum moment occurs at a = L/2.
  - Target 0.5 %.

## M4 — vehicle, envelopes and critical positions

- **Vehicle struct:** axle magnitudes (positive downward input, converted to −P), spacings, and one documented reference axle. The policy for axles exactly at the bridge ends or supports must be decided and recorded in DECISIONS.md.
- **Position stepping:** from fully off the bridge to fully off again.
- **Envelopes and critical positions:** M, V and δ envelopes as max/min over positions at each x. Track the quantity, sign, x, the vehicle position x_v and the axle set separately.
- **Step refinement:** refine the step near the extremes.
- **Efficiency:** factorize K_ff once and reuse it for every position.
- **Tests:** single-axle reduction to Benchmark B, superposition of multiple axles, axles entering and leaving, and convergence with step size.

## M5 — materials

- Input layer: steel (E_s, I_s) or RCC (E_c, I_eff supplied by the user). Both produce EI per element, and there is no material branch inside the solver.
- **Test:** steel and RCC models with equal assigned EI give identical results. This checks input and solver consistency, **not** concrete behaviour.
- No nonlinear cracking.

## M6 — basic GUI

- An App Designer front end that calls only `src/` functions.
- Sage-green styling. Conventional pin, roller and fixed-wall symbols.
- Inspection views for k_e, K, the free and restrained DOFs, F, U and R.
- **Needs MATLAB.** Claude Code cannot run or check App Designer in this environment, so GUI behaviour must be confirmed by the user. The numerical engine stays callable without the GUI.

## M7 — Stage 2

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

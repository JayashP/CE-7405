# CE 7405 — Interactive Matrix-Based Bridge Analysis and Condition Assessment Platform

This is a MATLAB direct-stiffness solver for a **2D equivalent Euler–Bernoulli bending beam** (spec Option A). Each node has two DOFs: v (vertical displacement) and θ (rotation).

- **Course:** CE 7405, Statically Indeterminate Structures, LSU, Fall 2026.
- **Deadline:** 24 Nov 2026.
- **Authoritative requirements:** `PROJECT_SPEC.md`.

## Current status (2026-10-29, milestone M2 on branch `claude/m2-indeterminate-beams`)

| Capability | State |
|---|---|
| 4×4 beam element stiffness, global assembly, pin/roller/fixed supports, under-restraint detection | Implemented; tested in GNU Octave 8.4.0 |
| Linear static solve (K_ff U_f = F_f), reactions, element end shear/moment | Implemented; tested in GNU Octave 8.4.0 and MATLAB R2026b (M1) |
| Benchmark A (simple span, central load: R = 50 kN, M_max = 500 kN·m, δ = 8.333 mm) | **PASS** in GNU Octave 8.4.0 (error ≤ about 1e‑9 %) and in MATLAB R2026b (26/26 tests; VERIFICATION_LOG V-002) |
| Multi-span mesher, uniform loads (consistent loads, f_e = k_e q_e − f_e0), sampled V/M diagrams | Implemented (M2); tested in GNU Octave 8.4.0; **MATLAB NOT RUN yet** |
| Benchmark C (propped cantilever, UDL) and D (two-span, UDL), plus point-load and pattern-load indeterminate checks | **PASS in Octave**, error ≤ about 4e‑11 % (target 0.5 %); **MATLAB NOT RUN yet** |
| Point loads inside elements, deflection between nodes, moving loads, envelopes, vehicles | Not implemented (M3 next, then M4) |
| Steel/RCC input layer, GUI, Stage 2 damage, Stages 3/4 | Not implemented |

See `VERIFICATION_LOG.md` for the actual numbers and `DEVELOPMENT_PLAN.md` for what comes next.

## Run the tests

From the repository root, in MATLAB:

```matlab
addProjectPaths;
runAllTests;          % prints comparison tables and a PASS/FAIL summary; errors if any test fails
```

From a terminal, in MATLAB:

```bash
matlab -batch "runAllTests"
```

From a terminal, in GNU Octave:

```bash
octave-cli --no-gui --norc --eval "runAllTests;"
```

## Use the engine (no GUI needed)

```matlab
addProjectPaths;
L = 20;  EI = 200e9 * 0.01;                         % SI units: m, N*m^2
model = createBeamModel(generateUniformMesh(L, 20), EI);
model = addSupport(model, findNodeAtX(model, 0), 'pin');
model = addSupport(model, findNodeAtX(model, L), 'roller');
model = addNodalLoad(model, findNodeAtX(model, L/2), -100e3);   % 100 kN DOWNWARD -> negative
res = solveStaticModel(model);
res.reactions            % node, Fv [N] (+ up), Mz [N*m] (+ CCW)
res.v(11)                % midspan v [m] (+ up)  -> -8.333e-3
max(res.elementForces.moment(:))   % +5e5 N*m (sagging positive)
full(res.K), res.freeDofs, res.F, res.U, res.R   % matrices and vectors for inspection
```

Two-span continuous beam with a 20 kN/m downward uniform load (Benchmark D):

```matlab
[x, xs] = meshSpans([10 10], 16);                  % node at every support
model = createBeamModel(x, EI);
model = addSupport(model, findNodeAtX(model, xs(1)), 'pin');
model = addSupport(model, findNodeAtX(model, xs(2)), 'roller');
model = addSupport(model, findNodeAtX(model, xs(3)), 'roller');
model = addUniformLoad(model, -20e3);               % downward -> negative [N/m]
res = solveStaticModel(model);
s = sampleInternalForces(model, res.U, 8);           % s.x, s.V, s.M for diagrams
min(s.M)                                             % -2.5e5 N*m = -qL^2/8 over the middle support
```

Main functions (see `help <name>`):

| Function | Purpose |
|---|---|
| `beamElementStiffness(EI, Le)` | 4×4 element matrix, DOFs `[v1 θ1 v2 θ2]` |
| `generateUniformMesh(L, ne)` | Node coordinates |
| `createBeamModel(x, EI)` | Model struct from coordinates and EI (scalar or per element) |
| `addSupport(model, node, 'pin'\|'roller'\|'fixed')` | Add a support at a node |
| `addNodalLoad(model, node, Fv, Mz)` | Add a nodal load |
| `findNodeAtX(model, x)` | Node at a coordinate; errors if there is none |
| `assembleGlobalK(model)` | Global stiffness matrix |
| `meshSpans(spanLengths, elementsPerSpan)` | Node coordinates for multi-span beams, with a node at every support |
| `elementsBetween(model, x1, x2)` | Element indices between two node coordinates (e.g. one span) |
| `addUniformLoad(model, w, elements)` | Uniform load w [N/m] (+ up, so downward is negative) on all or selected elements |
| `equivalentDistributedLoad(w, Le)` | Consistent element load vector w·[L/2, L²/12, L/2, −L²/12] |
| `assembleNodalLoadVector(model)` / `assembleLoadVector(model)` | Global load vector: nodal only / nodal + element loads |
| `partitionDofs(model)` | Free and restrained DOFs; stability check |
| `solveStaticModel(model)` | Full solve; returns a results struct |
| `recoverReactions(K, U, F, restrainedDofs)` | Support reactions |
| `recoverElementForces(model, U)` | Element end forces (k_e q_e − f_e0), end shear and moment |
| `sampleInternalForces(model, U, n)` | V and M at n+1 points per element (linear/parabolic under uniform load) |

**Conventions** (DECISIONS.md D-002/D-003):
- SI units inside the engine.
- v positive upward, θ positive counterclockwise.
- Applied downward loads are negative.
- Bending moment positive sagging; V(x) = sum of upward forces left of the section.

## Repository layout

```text
PROJECT_SPEC.md        authoritative requirements (verbatim copy of the handoff spec)
DECISIONS.md           implementation decisions and open questions
DEVELOPMENT_PLAN.md    milestones and gates to 24 Nov
VERIFICATION_LOG.md    executed test evidence only
CHANGELOG.md           change history
addProjectPaths.m      path setup
runAllTests.m          test runner (MATLAB and Octave)
src/elements/          beamElementStiffness
src/model/             mesh, model struct, supports, loads, validation, DOF map, assembly
src/loads/             nodal, uniform-element and global load vectors
src/solver/            DOF partition, static solve, reactions, element forces
src/postprocess/       sampled shear and moment diagrams
src/util/              input-validation helpers
tests/                 script-based unit and benchmark tests (test*.m)
tests/helpers/         comparison/report helpers, portable runner, benchmark model builder
tools/                 mutation_check.py (test-sensitivity check)
results/verification/  raw test logs
```

## Ownership

- **Claude Code** owns source and tests, and records technical decisions and executed results.
- **Claude Cowork** writes human documentation from `DECISIONS.md`, `VERIFICATION_LOG.md` and `CHANGELOG.md`. It never claims capability that has no logged evidence.

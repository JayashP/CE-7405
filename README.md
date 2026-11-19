# CE 7405 — Interactive Matrix-Based Bridge Analysis and Condition Assessment Platform

This is a MATLAB direct-stiffness solver for a **2D equivalent Euler–Bernoulli bending beam** (spec Option A). Each node has two DOFs: v (vertical displacement) and θ (rotation).

- **Course:** CE 7405, Statically Indeterminate Structures, LSU, Fall 2026.
- **Deadline:** 24 Nov 2026.
- **Authoritative requirements:** `PROJECT_SPEC.md`.

## Current status (2026-11-19, milestone M9)

| Capability | State |
|---|---|
| 4×4 beam element stiffness, global assembly, pin/roller/fixed supports, under-restraint detection | Implemented; tested in GNU Octave 8.4.0 |
| Linear static solve (K_ff U_f = F_f), reactions, element end shear/moment | Implemented; tested in GNU Octave 8.4.0 and MATLAB R2026b (M1) |
| Benchmark A (simple span, central load: R = 50 kN, M_max = 500 kN·m, δ = 8.333 mm) | **PASS** in GNU Octave 8.4.0 (error ≤ about 1e‑9 %) and in MATLAB R2026b (26/26 tests; VERIFICATION_LOG V-002) |
| Multi-span mesher, uniform loads (consistent loads, f_e = k_e q_e − f_e0), sampled V/M diagrams | Implemented (M2); tested in GNU Octave 8.4.0 and MATLAB (46/46; V-004) |
| Benchmark C (propped cantilever, UDL) and D (two-span, UDL), plus point-load and pattern-load indeterminate checks | **PASS** in Octave (error ≤ about 4e‑11 %, target 0.5 %) and in MATLAB (V-004) |
| Point loads at any position (Hermite consistent loads, not snapped), shear jumps, deflection at any x | Implemented (M3); tested in GNU Octave 8.4.0 and MATLAB (61/61; V-006) |
| Benchmark B (single load at 88 positions on a coarse 8-element span) | **PASS** in Octave (error ≤ about 7e‑12 %, target 0.5 %) and in MATLAB (V-006) |
| Multi-axle vehicles, quasi-static moving-load stepping (both directions), M/V/v and reaction envelopes, critical vehicle positions with step refinement | Implemented (M4); tested in GNU Octave 8.4.0 and MATLAB (74/74; V-008) |
| Moving-load benchmarks (two-axle absolute maximum moment, spec 3-axle truck 1349.1 kN·m, two-span negative moment and uplift) | **PASS** in Octave (error ≤ about 1e‑5 %, target 0.5 %) and in MATLAB (V-008) |
| Steel (E_s·I_s) and RCC (E_c·I_eff, user-supplied, constant) material input, per span; equal-EI steel/RCC equivalence | Implemented (M5); tested in GNU Octave 8.4.0 and MATLAB (82/82; V-010) |
| MATLAB app `BridgeConditionApp` (code-built; sage green until M8, MATLAB-style colours since M9): model, vehicle and moving-load view, envelopes, matrices, verification | Implemented (M6). MATLAB: 95/95 tests, scripted app check 27/27, all 5 tabs used (V-012). Octave: same results against stand-in components (V-011) |
| Stage 2: prescribed EI loss EI_D = (1 − d)EI per element, healthy vs damaged moving-load comparison, sensitivity sweep over locations | Engine implemented (M7); 104/104 tests in GNU Octave and MATLAB (V-014). App tab "Damage (Stage 2)" (M7b): 106/106 and 33/33 in MATLAB (V-016). Display revisions M7c (sub-tabs, findings text, no −0.000): 107/107 and 33/33 in Octave (V-017); MATLAB not run yet |
| Stage 3: single-region inverse search from sensor deflections (241-structure scan + 1 % refinement, RMSE, competing candidates, region of uncertainty) | Engine implemented and revised after an independent review (D-028, D-029): exact on noise-free synthetic data; with a stated noise level, a likelihood-ratio region of uncertainty, a fit check and selectable candidate region size. Octave results and the 20-seed coverage study in V-019; MATLAB 129/129 tests and app check (V-020). App tab "Identification (Stage 3)" (M8): verified in Octave (V-021) and MATLAB (V-022: 135/135 tests, app check all PASS). Synthetic data only, not field validation |
| Input redesign (M9, D-031): span, support and axle tables with + / - buttons, support letters A, B, C with type drop-downs, vehicle presets (spec truck, AASHTO HL-93 axles), node drop-downs for regions, one SI / US customary unit switch for every input and result, MATLAB-style colours | Implemented. GNU Octave: see VERIFICATION_LOG V-025. MATLAB: **not run yet** |
| Stage 4 (repair categories) | Not implemented |

See `VERIFICATION_LOG.md` for the actual numbers and `DEVELOPMENT_PLAN.md` for what comes next.

## Open the app (MATLAB)

From the repository root:

```matlab
addProjectPaths;
app = BridgeConditionApp;            % opens the app window (MATLAB-style colours)
checkBridgeConditionApp(true)        % optional: scripted check of the app against the engine
```

The app has no calculations of its own: every number comes from the tested functions in `src/` (DECISIONS.md D-023).

Choose the unit system first (top of the Bridge model tab): **SI** (m, kN, GPa, mm) or **US customary** (ft, kip, ksi, in). Every input and result follows it; the engine always works in SI. A switch is refused while a span, support or axle entry is invalid: correct it first. Enter the spans in the span table (**+ Add span** adds a row), pick a type for each support A, B, C, ... (Pin, Roller, Fixed, Free), then press **Apply model**. The box under the drawing summarises the model and states what it is and is not (2D beam, pin = roller in bending, not a load rating). On the Vehicle tab, pick a preset or edit the axle table, then press **Apply vehicle**.

Tabs: Bridge model · Vehicle & moving load · Envelopes · Damage (Stage 2) · Identification (Stage 3) · Matrices · Verification. On the Damage tab, choose a region by its first and last node and a loss d in %, press **Apply damage**, then **Compare healthy vs damaged** or **Run sensitivity** (DECISIONS.md D-026). d is a loss of model flexural rigidity, not a measure of real damage.

On the Identification tab, check the sensors and truck positions, press **Generate synthetic readings** (a hidden test case) or **New empty table** (type measured deflections in mm or in), state the reading noise and press **Run identification** (DECISIONS.md D-030). It reports where effective stiffness may have changed, with a region of uncertainty; on synthetic readings this checks the algorithm, not a real bridge.

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

Steel span plus RCC span (EI = E·I; I_eff for RCC is supplied by you and held constant):

```matlab
[x, xs] = meshSpans([10 15], [8 12]);
steel = defineMaterial('steel', 200e9, 0.01);               % Es [Pa], Is [m^4]
rcc = defineMaterial('rcc', 32e9, 0.03125, 'RCC span', 'Ieff from external cracked-section check');
model = createBeamModel(x, steel);
model = assignMaterial(model, rcc, elementsBetween(model, xs(2), xs(3)));
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

Point load between nodes (no snapping), deflection at a sensor location:

```matlab
model = createBeamModel(generateUniformMesh(20, 8), EI);   % 2.5 m elements
model = addSupport(model, 1, 'pin');
model = addSupport(model, 9, 'roller');
model = addPointLoad(model, 7.77, -100e3);                 % 100 kN down at 7.77 m
res = solveStaticModel(model);
res.R(1)                                                   % R_A = 61.15e3 N
s = sampleInternalForces(model, res.U, 4);                 % V jumps by -100 kN at 7.77 m
evaluateDeflection(model, res.U, [5 7.77 10])              % deflection [m] at any x
```

Stage 2, a 30 % EI loss in the elements between 8 and 10 m, compared with the healthy beam (same truck as below):

```matlab
damaged = applyStiffnessDamage(model, elementsBetween(model, 8, 10), 0.30);   % EI_D = 0.7 EI there
cmp = compareHealthyDamaged(model, damaged, truck, 'Step', 0.1);
[cmp.critical.healthy; cmp.critical.damaged]       % global extremes before / after
[cmp.reactions.pctChangeMax]                       % % change of maximum reactions (NaN if healthy = 0)
s = damageSensitivity(model, truck, 0.30, 'vmin'); % move the same loss along the beam; s.rank = most influential first
```

Moving truck (spec 3-axle example, 80/120/120 kN, spacings 4.2 m and 1.4 m) on the same span:

```matlab
model = createBeamModel(generateUniformMesh(20, 8), EI);
model = addSupport(model, 1, 'pin');
model = addSupport(model, 9, 'roller');
truck = createVehicle([80e3 120e3 120e3], [4.2 1.4], '3-axle example');
ml = runMovingLoad(model, truck, 'Step', 0.1);       % front axle is the reference x_v
ml.critical(1)                % max M = 1.349e6 N*m at x = 9.74 m for x_v = 13.94 m
plot(ml.stations, ml.envelope.Mmax/1e3, ml.stations, ml.envelope.Mmin/1e3)   % kN*m
[ml.reactions.node, ml.reactions.Rmax/1e3]           % max reactions [kN]
```

Main functions (see `help <name>`):

| Function | Purpose |
|---|---|
| `beamElementStiffness(EI, Le)` | 4×4 element matrix, DOFs `[v1 θ1 v2 θ2]` |
| `generateUniformMesh(L, ne)` | Node coordinates |
| `createBeamModel(x, EI)` / `createBeamModel(x, material)` | Model struct from coordinates and EI (scalar or per element) or a material |
| `defineMaterial('steel'\|'rcc', E, I, name, basis)` | Steel E_s·I_s or RCC E_c·I_eff (I_eff supplied by you, constant) |
| `assignMaterial(model, material, elements)` | Give elements or spans a material (EI = E·I) |
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
| `addPointLoad(model, x, Fv)` | Point load at any coordinate x [m]; Fv [N] (+ up, so downward is negative) |
| `beamShapeFunctions(r, Le)` / `equivalentPointLoad(P, a, Le)` | Hermite shape functions / consistent point-load vector |
| `locatePointLoads(model)` | Node or element (and local position) carrying each point load |
| `sampleInternalForces(model, U, n)` | V and M at n+1 points per element plus both sides of every interior point load |
| `evaluateDeflection(model, U, xq)` | Deflection at any coordinates (sensors), exact inside loaded elements |
| `createVehicle(axleLoads, axleSpacings, name)` | Vehicle: axle load magnitudes [N] (positive = down), spacings [m] front to rear |
| `vehicleAxlePositions(vehicle, xv, direction)` | Axle coordinates for front-axle position x_v |
| `generateVehiclePositions(model, vehicle, step, direction)` | Positions for a full crossing (entry to exit) |
| `runMovingLoad(model, vehicle, 'Step', h, ...)` | Envelopes, reaction envelopes, critical positions (with refinement) |
| `prepareMovingLoad(model, stations)` / `analyzeVehiclePosition(prep, vehicle, xv)` | Factorize once / response at one vehicle position (e.g. a GUI slider) |

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
src/elements/          beamElementStiffness, beamShapeFunctions
src/materials/         steel / RCC material records and assignment
src/gui/               app helpers: input parsing, model/vehicle builders, table data, theme
src/visualization/     drawing primitives (beam, supports, loads, truck) and diagram plots
app/                   BridgeConditionApp.m (code-built MATLAB app)
src/model/             mesh, model struct, supports, loads, validation, DOF map, assembly
src/loads/             nodal, uniform-element and global load vectors; vehicles and positions
src/solver/            DOF partition, static solve, reactions, element forces
src/postprocess/       sampled shear and moment diagrams, deflection at any x
src/movingload/        factorize-once moving-load analysis, envelopes, critical positions
src/damage/            Stage 2: prescribed stiffness loss, healthy vs damaged comparison, sensitivity
src/inverse/           Stage 3: sensor deflections, single-region inverse search, synthetic noise
src/util/              input-validation helpers
tests/                 script-based unit and benchmark tests (test*.m)
tests/helpers/         comparison/report helpers, portable runner, benchmark model builder
tests/gui/             checkBridgeConditionApp.m (scripted app check; MATLAB, or Octave with tools/gui_mock)
tools/                 mutation_check.py (test-sensitivity check), moving_load_reference_check.py
tools/gui_mock/        Octave stand-ins for UI components (development check only)
tools/preview/         drawing previews via matplotlib (development check only)
results/verification/  raw test logs
```

## Ownership

- **Claude Code** owns source and tests, and records technical decisions and executed results.
- **Claude Cowork** writes human documentation from `DECISIONS.md`, `VERIFICATION_LOG.md` and `CHANGELOG.md`. It never claims capability that has no logged evidence.

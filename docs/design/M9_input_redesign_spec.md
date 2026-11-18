# M9 input redesign — implementation spec (2026-11-19)

User decisions (record as DECISIONS.md D-031 when integrating):
1. **One global unit system** for every input and result: `unitSystem('SI')` (m, mm, kN, kN*m, kN/m, GPa, m^4) or `unitSystem('US')` (ft, in, kip, kip*ft, kip/ft, ksi, in^4). The engine stays SI. `src/gui/unitSystem.m` is final; read it first.
2. **One material for all spans.** 3. **Support types: Pin, Roller, Fixed, Free** (no guided). 4. **Vehicle presets** wanted.
5. **App colours: MATLAB style** (light grey window, white panels, blue #0072BD action buttons, MATLAB line colours blue/orange/purple/dark red; yellow/green/cyan only as fills). **Slides stay sage** (not code).

Rules for every part: MATLAB R2024+ **and** GNU Octave 8.4, no toolboxes; help text and `BridgeFE:` error ids in the repo style; **never change an existing analytical reference or an existing test expectation**; all existing tests must still pass (`octave-cli --no-gui --eval "addProjectPaths; runAllTests"`, about 8 min); do **not** edit `app/BridgeConditionApp.m`, `tools/mutation_check.py`, `DECISIONS.md`, `CHANGELOG.md`, `VERIFICATION_LOG.md`, `README.md`, `DEVELOPMENT_PLAN.md` (the integrator does); put new tests in the new test file named for your part; propose mutants (name, file, exact old string, new string) in your report instead of editing the mutation tool.

## Part A — results in the chosen units (`claude/m9-units-display`)

Every helper below gets an optional **last** argument `U` (default `unitSystem('SI')`). With `U` omitted or SI its output must be **identical** (`isequal`) to today's. With US, numbers and unit texts (column headers, labels, summary text) change to US units.

| Function | Converts |
|---|---|
| `quantityDisplay(code, U)` | M → `U.moment`, V and R → `U.force`, v → `U.deflection` (scale = 1/toSI, label/unit text from U) |
| `criticalTableData(ml, U)` | values by quantity; x, x_v, axle positions in `U.length`; headers with units |
| `reactionEnvelopeTableData(ml, x, U)`, `currentReactionTableData(res, model, U)` | forces `U.force`, couples `U.moment`, positions `U.length`; headers |
| `damageComparisonTableData(cmp, U)`, `damageComparisonSummary(cmp, model, U)` | via `quantityDisplay`; reactions `U.force` |
| `sensitivityTableData(s, model, U)`, `plotSensitivity(ax, s, model, color, U)` | x ranges and x axis in `U.length`; values via `quantityDisplay` |
| `fitProfileData(result, model, U)`, `plotFitProfile(ax, p, x, th, U)` | `p.x1/x2` in `U.length`; `plotFitProfile` takes node x **already in display length**; x label unit |
| `identificationTableData(result, U)`, `identificationSummary(result, truth, U)` | region x `U.length`, RMSE and absolute noise `U.deflection` |
| `plotReadings(ax, positions, sensorX, uObs, uHealthy, uBest, th, U)` | inputs stay SI; x axis `U.length`, y axis `U.deflection` |
| `readingsFromTable(data, nS, nP, U)` | table in `U.deflection` → m |
| `identificationOptions(model, regionLength, noisePercent, noiseAbsolute, direction, U)` | `regionLength` is SI m (from `candidateRegionLength`); `noiseAbsolute` in `U.deflection` → m |
| `candidateRegionLength(label, U)` | items SI: `Each element`, `2 m regions`, `4 m regions` → [0 2 4] m; US: `Each element`, `6 ft regions`, `12 ft regions` → [0 1.8288 3.6576] m (always returns metres) |
| **new** `nodeChoices(model, U)` | `[labels, xSI]`: one entry per node, label `node 7 (x = 7.5 m)` in display length, `xSI` the node coordinates in m (for region drop-downs) |

`plotEnvelope`, `plotEnvelopeComparison`, `plotDiagram`, `responseDiagramData`, `identificationDefaults`, `syntheticObservations`, `damageModelFromInputs` stay SI (the app scales or passes SI).

Tests: new `tests/testUnitsDisplay.m`: unit factors against independent constants (ft 0.3048, in 0.0254, lbf 4.4482216152605 N); for every function above, the US output equals the SI quantity converted (parse numbers with `str2double`; tolerance = display rounding) and its headers/labels carry US units; SI output `isequal` to the call without `U`.

## Part B — table inputs, presets, drawing labels (`claude/m9-input-tables`)

| Function | Spec |
|---|---|
| **new** `supportLetters(n)` | `{'A','B',…,'Z','AA','AB',…}` |
| **new** `supportTypeList()` | `[labels, engineTypes]` = `{'Pin','Roller','Fixed','Free'}`, `{'pin','roller','fixed','none'}` |
| **new** `buildModelFromTables(in, U)` | `in.spanLengths` (row, display length), `in.elementsPerSpan` (same size, integers 1–2000), `in.supportTypes` (cellstr of labels from `supportTypeList`, one per span end, case-insensitive), `in.materialType` ('steel'/'rcc'), `in.E` (display modulus), `in.I` (display inertia), `in.udlDown` (display distributed load, ≥ 0), optional `in.materialName`, `in.materialBasis`. Converts to SI and builds the model only with verified engine functions (`meshSpans` with per-span element counts, `defineMaterial`, `createBeamModel`, `findNodeAtX`, `addSupport`, `addUniformLoad`, `partitionDofs`). `info`: `supportX` (m), `supportLetters`, `supportTypes` (labels), `warnings` (unit warning via `lastwarn`, as `buildModelFromInputs`), `summary` lines **in display units** (spans with total, elements per span, supports with letters and x, material with E, I and EI, permanent load). Errors name the row: `Span 2: length must be a positive number`, `Support C: unknown type`. |
| **new** `vehicleFromTable(axleLoads, spacings, name, U)` | loads in `U.force` (> 0), spacings in `U.length` (`numel(loads) - 1`, `[]` for one axle) → `createVehicle(loads*toSI, spacings*toSI, name)`; errors name the axle row |
| **new** `vehiclePresets(U)` | struct array `name, loads, spacings, note` in display units: (1) `Illustrative 3-axle truck (spec)`: 80, 120, 120 kN; 4.2, 1.4 m. (2) `AASHTO HL-93 design truck (axles only)`: 8, 32, 32 kip; 14, 14 ft (rear spacing is variable 14–30 ft in AASHTO LRFD 3.6.1.2.2; 14 ft used); note states: axle loads only, no design lane load, no dynamic load allowance. (3) `Custom` (empty loads: the app keeps the table). Values convert exactly between systems. |
| `bridgeDrawing` new options | `Units` (U, default SI) for load and axle label texts; `EndLabels` struct with fields `x` (m) and `text` (cellstr) drawn bold below the span ends (y ≈ −1.55 h, below the support symbols). **Declutter:** adjacent on-beam axles closer than about 6 % of the beam length share one label (`2 x 120 kN`, or `80 + 120 kN` when different); the permanent-load label sits at the left end of the load, left-aligned, not at mid-length |
| `renderDrawing(ax, prims, U)` | optional U: draws every coordinate divided by `U.length.toSI` (uniform scale, shapes kept) and labels the axis `x [ft]` / `x [m]` |

Tests: new `tests/testInputTables.m`: SI tables with equal element counts give a model `isequal` to `buildModelFromInputs` with the same inputs; per-span element counts; US inputs convert exactly (node x = meshSpans(ft × 0.3048, …), E = ksi factor × value, I, load); every error message names its row; letters beyond Z; presets convert exactly both ways and `vehicleFromTable` of the HL-93 preset gives axle loads 35585.77 N and 142343.09 N and spacings 4.2672 m; drawing: end labels, unit texts, merged axle labels, left-aligned load label; `renderDrawing` stand-in not needed (test `bridgeDrawing` primitives only).

## Part C/D — colours and app integration (integrator)
`appTheme` MATLAB style; Bridge model and Vehicle tabs with tables, + / − buttons, drop-downs, unit-system drop-down; region inputs as node drop-downs (`nodeChoices`); every display through U; app check rewritten.

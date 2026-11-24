# Changelog

This file records every notable change to the source, tests and project records. Format based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/). Dates are ISO 8601.

## [0.11.0-M10] — 2026-11-24 (branch `claude/m10-gui-clarity`, from M9c)

GUI clarity, requested by the user after the user guide (DECISIONS.md D-032). No change to any analysis result.

### Added
- x and x_v explained in a grey line under the Envelopes critical and reaction tables, the Damage sensitivity table, the Identification readings and candidate tables; the slider readout says "front axle, measured from A".
- Identification tab: sensors and truck positions in two tables (rows S1, S2, ... and P1, P2, ...) with **+ Add** (one spacing after the last, capped at the beam end or the end of the crossing) and **- Remove** (at least one stays). Errors name the row ("Sensor 2: x = 30 m is not on the beam (0 to 27 m).", "Truck position 3: x_v must be a number (m)."). Defaults after Apply model; a unit switch keeps and converts them, with the exact restore on switching back. `coordinatesFromTable`.
- Formatted information boxes (MATLAB `uihtml`): model summary (two columns: model, supports one per bullet, material, permanent load, modelling notes in grey), moving-load notes, applied damage, findings, identification box and Summary (Method, Result, Checks and flags, Synthetic test case, Notes). Numbers highlighted in blue, limiting flags orange with a warning sign, a passed fit check green with a tick. The engine's wording is unchanged. `htmlPanel`, `infoPanelHtml`; GUI stand-in `uihtml`.
- `materialModulusRange` (the plausible-E range, shared by `defineMaterial` and `buildModelFromTables`); test helper `errorMessage`.

### Changed
- Healthy vs damaged plots: four solid curves told apart by colour: healthy max blue, healthy min lighter blue (thin, on top), damaged max dark red, damaged min orange (thick). `plotEnvelopeComparison` takes [max; min] colour rows; theme fields `healthyMax`, `healthyMin`, `damagedMax`, `damagedMin`.

### Fixed (the 9 problems listed in the user guide)
- Ticking "Show node and element numbers" during a preview redrew the applied model; the preview is kept, and the Damage drawing is redrawn too.
- The damaged / hidden region "to left of from" message quoted metres in US units; it now quotes the node labels as shown.
- The unit-slip alert spoke of Pa; it now uses the unit typed (e.g. "E = 200 ksi is outside the usual 21755.7-36259.4 ksi").
- The sensor tooltip "e.g. L/4 L/2 3L/4" (text fields replaced by tables).
- Hidden loss limited to 0-60 %, the range the search covers.
- The sensitivity status no longer names a "most influential" element when no location changes the response (M, V, R of a determinate beam).
- E, I, material, material name, basis and uniform-load edits now show a preview and "Model edited: press Apply model".
- + Add span / - Remove last span keep the far-end support type (e.g. a Fixed end moves to the new end).
- The app help text (no longer "sage green", support "none").

### Fixed after the independent review of M10 (round 2)
- **+ Add** (sensors, truck positions) puts a point that gives non-zero readings and is not in the table yet: one spacing after the last entry (in the travel direction for truck positions, so a -x crossing gets a smaller x_v), else halfway to the end of the range, else the middle of the largest gap (supports count as gap ends for sensors). A sensor on a support or a truck position with no axle inside a span read zero and stopped the search. If no point is left the status says so; MATLAB scrolls the table to the new row (R2021b and later).
- Identification with a reading noise in % only: a sensor or truck position that reads zero is named ("Sensor 2 (x = 12 m) reads zero for every truck position (it is on a support). Remove it, or state Reading noise [mm] > 0.") instead of the engine's message about an option the app does not show.
- **- Remove last span** with a Free far end (cantilever tip) no longer moves "Free" onto the last support, which left an unstable beam; the last support stays as it was.
- Sensitivity status: ties and zero responses are judged against a physical size of the response (total load P, P*L for moments, P*L^3/EI for deflections), so round-off changes (1e-12 of the response) no longer name a "most influential" element; a response that is zero everywhere (e.g. the hogging moment of a simple span) shows "n/a" in the Change column with its own status.
- A unit switch that applies pending model or vehicle edits (a new span length, a vehicle, the travel direction) gives the default sensors and truck positions for the new model and says so; a pure unit switch keeps and converts yours, as before.
- Editing the sensor or truck-position table clears an identification result that belonged to the old entries.
- The preview redrawn after "Show node and element numbers" no longer overwrites the status line; the unit-slip check no longer prints the engine's warning in Pa on every preview (the app's message in the typed unit remains).
- The critical-table legend gets two lines (it was cut at one); the identification box shows the flags first and scrolls, and the Identification panel scrolls; the Summary lists the ratio method's warning ("No noise level stated ...") with the checks.
- Formatted boxes: a leading "+" sign is highlighted, element/node/section/seed numbers and step numbers are not, long words wrap, the warning and tick signs use the text form (they take the colour), the colour of an item is never read from its text, and the Summary has no repeated "Method" heading.
- GUI stand-ins: `uihtml` accepts only the properties the app uses; `scroll` for tables. `tools/crosscheck/replayV026.m` reads the new tables and boxes.

### Fixed after the second independent review of M10 (round 3)
- **+ Add** in US units: the new entry, shown with 6 digits, could sit a few micrometres off a support (65.6168 ft for a support at 65.6167979 ft: almost no reading) or repeat an entry converted from SI (32.8084 ft next to 32.8083989501 ft). Entries within 1e-5 of the range of a support or an entry are now skipped.
- Zero readings with a reading noise in % only: a truck position is named before a sensor (when no axle is inside a span every sensor reads zero, and the sensors are not at fault); a sensor that is not on a support is said to be on a span no truck position loads; a single zero reading (spans uncoupled by an interior Fixed support) is named ("Sensor 2 (x = 13.5 m) reads zero with the truck at position 1 (x_v = 6.75 m) ... state Reading noise [mm] > 0, or leave that reading empty (missing)."). Missing readings are left out, as in the engine, so a run the engine accepts is no longer refused.
- Sensitivity status: on a statically determinate beam (2 restrained DOFs), M, V and R are "the same for every location" by statics, whatever the mesh; the size of the changes is used only for an indeterminate beam (e.g. the hogging moment at a support from an overhang alone). With 600 elements on one span the round-off of the changes reached 3e-8 of the response, above the round-2 bound, and named a "most influential" element.
- A unit switch that applies a pending support-type, E, I, material or uniform-load edit now gives the default sensors and truck positions too (it compared only node positions, axles and direction).
- A redraw (node numbers, deformation scale) during an invalid pending edit no longer replaces the status with the input error.
- GUI stand-in: `uihtml` refuses visual properties set after construction as well. `testGuiHelpers` checks what is printed (`evalc`), not `lastwarn`: MATLAB records a warning that is turned off in `lastwarn`, Octave does not, so the round-2 assertion would have failed in MATLAB.

### Fixed after the third independent review of M10 (round 4)
- The round-3 order (truck positions first) could blame a truck position that has axles on the bridge: with every sensor on a support ("Truck position 1 (x_v = 5 m) gives zero readings at every sensor" instead of "Sensor 1 (x = 0 m) ... (it is on a support)"), or with missing readings. A truck position is now named only when the whole beam is still (no deflection at any element midpoint); a sensor when its predicted readings are zero for every truck position (missing ones included); otherwise the first zero reading.
- A sensor at a Free tip is no longer said to be "on a support" (the span ends listed in the model include Free ends); + Add likewise treats only real supports as places to avoid.
- (Round 5, after a fourth review.) A sensor typed at a support as the table shows it (39.3701 ft for a Fixed support at 39.3700787 ft) sits a few micrometres off it; its readings then straddle the zero bound, and the message said "no axle loads its span". A sensor within the display rounding of a support (1e-5 of the largest coordinate, the tolerance + Add uses; 123 um for 131.234 ft) is now named "on a support".

### Fixed after the MATLAB run (V-030)
- The M, V and v diagrams on the Vehicle tab no longer label round-off as a peak: the user's MATLAB screenshot showed "-1.164e-13" at the pinned end of a simple span. `plotDiagram` now labels a maximum or minimum only when it is more than 1e-9 of the largest magnitude of the diagram (a relative bound, so the same in every unit). testGuiHelpers checks the screenshot case, a round-off maximum, a small real minimum (-1e-6 against 219.2, still labelled) and the same diagram scaled by 1e-12; 4 new mutants, all detected.

### After the MATLAB Online test (presentation day)
- `openBridgeApp.m` opens the app in one step (MATLAB Online link and QR code in the README and `docs/presentation/`).
- The app figure is set to the light theme where MATLAB supports themes (R2025a and later): in MATLAB Online with the dark theme, tables, fields and axes followed the dark theme while the app's own panels stayed light. Octave app check 118/118 (the stand-ins have no Theme property, so the branch is skipped there); not yet seen in MATLAB.

## [0.10.1-M9c] — 2026-11-19 (branch `claude/m9c-polish`)

Cosmetic follow-ups from the user's MATLAB screenshots of M9 (VERIFICATION_LOG V-026 part 2a), revised after an independent review. No change to any result; the `src/` changes are display only (plot title, label clipping and placement).

### Changed
- Position slider: round tick values (1, 2 or 5 x 10^k, 4 to 10 intervals, so labels stay apart on a restored window too). MATLAB's automatic ticks also labelled the non-round end of the crossing, next to the last round tick ("120126.4" in US units). Ticks are clamped inside the limits and never -0.
- Left input panels 400 -> 460 px on every tab, so the vehicle name and five truck positions fit their fields.
- Current-reaction table: headers "Force [kip]" and "Couple [kip*ft]", with the sign rule in the label above ("Support reactions (forces + up, couples + CCW)"), so the table fits without a horizontal scroll bar. The helper `currentReactionTableData` is unchanged.
- Choosing a vehicle preset, editing the axle table, the vehicle name, the position step or the travel direction sets the status "Vehicle edited: press "Apply vehicle" to use it (the drawing shows the applied vehicle)."; **Apply vehicle** reports "Vehicle applied: <name>, <n> axle(s), total <load>" unless an error was reported while placing the vehicle.
- `plotReadings`: second title line "markers: readings, solid: fit, dotted: healthy" (shorter, for the narrower readings plot).
- Axle labels (user's US screenshot: the spec truck's rear axles, off the bridge, read "26.9771 k26.9771 kip"): neighbouring axles share one label when their labels would overlap, estimated from the label length, instead of when closer than 6 % of the span; off-bridge axles follow the same rule. Two M9b mutants of the 6 % threshold were replaced by two M9c mutants of the width rule; `testInputTables` asserts the merged off-bridge label and the kip case on a 20 m span.
- Labels clipped to the axes (user's MATLAB screenshot after a zoom: node, element and axle labels showed outside the drawing): `renderDrawing` and `plotDiagram` draw text with `'Clipping', 'on'`, so a label whose point leaves the zoomed view is hidden with it. Diagram peak labels sit on the side of their point that faces the inside of the plot. Test: `testGuiHelpers` (66 drawing labels, peak-label sides); `RecordingAxes` records `text` calls. App check: 93 rows.
- GUI stand-in slider: `MajorTicks` must be increasing and inside `Limits`.
- App check: 93 rows (round slider ticks in US units and on a -x crossing; status after a preset, an axle edit, a direction or step edit and Apply vehicle; reaction headers and label; labels clipped). `tools/app_mutation_check.py`: 10 M9c faults; `tools/mutation_check.py`: 3 M9c faults.

## [0.10.0-M9] — 2026-11-19 (branch `claude/m9-input-redesign`)

Input redesign requested by the user (DECISIONS.md D-031): tables and drop-downs instead of typed lists, one SI / US unit switch, vehicle presets, MATLAB-style colours.

### Added
- `src/gui/unitSystem` (SI: m, mm, kN, kN*m, kN/m, GPa, m^4; US: ft, in, kip, kip*ft, kip/ft, ksi, in^4; exact NIST SP 811 factors). The engine stays SI.
- Part A, results in the chosen units: optional last argument `U` for `quantityDisplay`, `criticalTableData`, `reactionEnvelopeTableData`, `currentReactionTableData`, `damageComparisonTableData`, `damageComparisonSummary`, `sensitivityTableData`, `plotSensitivity`, `fitProfileData`, `plotFitProfile`, `identificationTableData`, `identificationSummary`, `plotReadings`, `readingsFromTable`, `identificationOptions`, `candidateRegionLength`. Without `U` the output is unchanged (isequal). New `nodeChoices`. Optional x-axis label for `plotDiagram`, `plotEnvelope` and `plotEnvelopeComparison`.
- Part B, table inputs: `supportLetters`, `supportTypeList` (Pin, Roller, Fixed, Free), `buildModelFromTables` (per-span element counts; errors name the row, e.g. "Span 2: ...", "Support C: ..."), `vehicleFromTable` ("Axle 2: ..."), `vehiclePresets` (spec 3-axle truck; AASHTO HL-93 design truck, axle loads only; custom). `bridgeDrawing` options `Units` and `EndLabels`; close axles share one label; the load label sits at the left end of the load. `renderDrawing` draws in the display length unit.
- App:
  - Bridge model tab: unit-system drop-down; span table with **+ Add span** / **- Remove last span**; supports table lettered A, B, C, ... with a type drop-down; one material for all spans. Edits are previewed in the drawing; **Apply model** analyses them.
  - Vehicle tab: preset drop-down with a note, axle table with **+ Add axle** / **- Remove last axle**, total load and length line.
  - Damage and Identification tabs: regions chosen on node drop-downs; support drop-down for the reaction sensitivity.
  - Every input and result in the chosen units. A unit switch converts every input (12 significant digits) and restores inputs not edited since the last switch exactly, so SI -> US -> SI gives the same model.
  - Support letters drawn under the span ends.
- Tests: `tests/testUnitsDisplay.m`, `tests/testInputTables.m`, `tests/helpers/RecordingAxes.m`; app check rewritten for the new controls (89 rows without the in-app test run); M9a/M9b mutants; 31 app mutants against the app check.

### Fixed (independent review of the integration)
- A unit switch with an invalid model or vehicle input left the sensor text, the node drop-downs and (with both invalid) the slider in the old units under new labels. The switch is now refused until the input is corrected.
- The Identification readings tab kept the title "Readings [mm]" in US units (the table holds inches).
- A switch could swap E between the steel and RCC defaults when E equalled the other material's default.
- After an added axle or span, the switch back no longer restored the unedited rows exactly (80.0000000001 kN).
- Emptied result tables kept SI headers after a switch; the reading-noise tooltip and the empty-table hint said mm.
- A sensor typed at the beam end as displayed (e.g. 65.6168 ft) was refused; it is now accepted and placed at the end.
- The app's table reader took numeric text as a number while Apply rejected it; both now treat text as not a number.
- Layout: the modelling notes had about 9 px on the user's window; they now sit under the model summary. Left panels scroll; the preset drop-down spans the panel; numeric fields show 6 digits instead of '2.901e+04'.
- App check: 13 gaps found by app mutants (slider, presets, add axle, sensors, noise and sweep step in US units; reaction envelope and supports tables; diagram x; Free support in the Rmax drop-down; hidden region apart from the damage region; errors reported by callbacks).
- App check (second review): the sweep wrote the private `LastError`; in MATLAB's child order it pressed "Run identification" before readings existed; it compared a uitable `ColumnName` with `isequal` (MATLAB returns n-by-1). New row: Apply model pressed in US units writes the default sensors and truck positions in ft.

### Changed
- `appTheme`: MATLAB-style colours (light grey window, white panels, blue #0072BD buttons; lines in blue, orange, purple and dark red; yellow only as a fill). Field names unchanged. Slides keep the sage theme.
- `drawingPrimitive` has a `fontWeight` field (default 'normal').
- `mutation_check.py`: four M6–M8 targets moved with the Part A code (same names, new target lines).
- GUI stand-ins (`tools/gui_mock`): containers list their children newest first (tab groups keep tab order) and uitable stores a 1-by-n `ColumnName`/`RowName` as n-by-1, as MATLAB does, so the Octave app check runs the callback sweep in MATLAB's order.

## [0.9.1-M8b] — 2026-11-18 (branch `claude/m8b-polish`)

Cosmetic follow-ups after the M8 MATLAB run (V-022).

### Fixed
- Envelopes critical and reaction tables and the current-reaction table no longer print `-0.000` (`formatNumber`).
- Readings table wide enough for five truck positions.
- `checkBridgeConditionApp` does not print the expected RCC caveat once per run; a row checks it instead (49 rows with the in-app test run).

## [0.9.0-M8] — 2026-11-12 (branch `claude/m8-identification-tab`)

Identification (Stage 3) tab in the app (D-030), plus display fixes from the S3b MATLAB screenshots.

### Added
- App tab "Identification (Stage 3)":
  - inputs: sensors, truck positions, synthetic hidden case or measured readings, stated noise, candidate region size;
  - outputs: drawing with sensors, region, best fit and hidden case; readings plot and table; fit-by-location chart; candidates table; summary.
- Public app methods `generateSyntheticReadings`, `newEmptyReadings`, `runIdentification`; properties `IdentTruth`, `IdentResult`.
- `src/gui`: `identificationDefaults`, `syntheticObservations`, `candidateRegionLength`, `identificationOptions`, `fitProfileData`, `identificationTableData`, `identificationSummary`, `readingsFromTable`, `numberListText`.
- `src/visualization`: `plotFitProfile`, `plotReadings`; `bridgeDrawing` options `Regions`, `BestRegion`, `BestLabel`, `TrueRegion`, `Sensors`.
- `appTheme`: colours `sensor`, `region`, `regionBest`, `truth`, `candidate`.
- `identifySingleDamage` result also records `ambiguityRatio`, `noiseLevel`, `noiseAbsolute`, `confidence`.
- Tests: `tests/testIdentificationHelpers.m`; 7 app-check rows (40 without the in-app test run); 9 M8 mutants; preview case F (Stage 3 drawing).

### Changed / fixed
- No empty legend boxes after clearing plots; no duplicate row numbers in the Damage tables; coordinates shown as 13.875 (not 13.88); shorter titles.
- **Latent bug since M6/M7b, found by the independent review:** objects drawn with `HandleVisibility 'off'` survived `cla`. `plotEnvelope`, `plotEnvelopeComparison`, `plotReadings` and `plotFitProfile` now build legends from explicit handles and hide nothing.
- Review fixes in the Stage 3 helpers (D-030): TeX label, chart layout, annotation bands, "no damage" best fit, zero-reading defaults, summary wording; a vehicle change keeps the user's sensors and hidden-case inputs.
- Mock components: `legend(ax, 'off')`, `legend(ax, handles, labels)`; graphics calls return numeric handles; `text(..., 'HandleVisibility', ...)`.
- After the MATLAB screenshots (2026-11-14):
  - best-fit star in the fit chart; sensor legend with colour and marker; two-line readings title; readings table `ColumnWidth` 'fit';
  - "Summary" sub-tab; left box with the best fit and every limiting flag (`identificationSummary` second output);
  - search-limit text uses the actual limit;
  - stand-ins store legends like MATLAB (`.String`) and keep them after `cla`; multi-line titles.

## [0.8.1-S3b] — 2026-11-11 (branch `claude/s3b-noise-region`)

Stage 3 revision: noise-based region of uncertainty (user's option 3) and candidate region size (option 2), then corrected after an independent multi-agent review (D-029).

### Added
- `identifySingleDamage` `'likelihood'` method (`'NoiseLevel'`, `'NoiseAbsolute'`, `'Confidence'`):
  - σ per reading from the healthy prediction; weighted misfit S; every group refined in 1 % steps; minimum between grid points;
  - likelihood-ratio region S − S_best ≤ χ²(0.95, 2);
  - fit check (`modelMisfit`, `gof`); `regionAtSearchLimit`; `minRMSE`; `rccBaseline` with warning `BridgeFE:rccInverse`.
- `src/inverse/chiSquareQuantile.m` (no toolbox), `src/inverse/candidateGroups.m` (regions of a chosen length), `src/inverse/hashSeed32.m`.
- `tests/testInverseUncertainty.m`; `tools/inverseNoiseStudy.m` now compares the ratio, χ² 1 m and χ² 2 m methods, plus an undamaged case.
- `tools/mutation_check.py`: S3b mutants; optional test-file filter; 1200 s timeout.

### Fixed
- `deterministicNormal`: consecutive seeds gave correlated noise (seed used as the LCG state); the seed is now hashed. The V-018 noise study is superseded.
- `identifySingleDamage`: a scalar `'Levels'` no longer crashes.

## [0.8.0-S3] — 2026-11-10 (branch `claude/s3-inverse-search`)

Stage 3 engine: single-region inverse stiffness-loss search from sensor deflections (D-028). No app tab yet.

### Added
- `src/inverse/predictSensorDeflections.m`: vehicle-only deflections at sensors for known vehicle positions.
- `src/inverse/identifySingleDamage.m`: healthy model once, 5 %–60 % coarse scan per group (241 structures for 20 elements), 1 % refinement, RMSE and normalized error, competing candidates, merged regions of uncertainty, search-limit flag, optional noise-consistency check.
- `src/inverse/addMeasurementNoise.m`, `src/inverse/deterministicNormal.m`: reproducible synthetic noise, identical in MATLAB and Octave.
- `tests/testInverseDamage.m` (8 tests, 115 in total): closed-form sensor deflections, blind noise-free cases, undamaged case, other mesh, missing data, one noise realization at 1–10 %, mirror ambiguity, 60 % limit, invalid input.
- `tools/inverseNoiseStudy.m`: noise study over seeds (results in V-018).
- `tools/mutation_check.py`: 7 S3 mutants.

## [0.7.2-M7c] — 2026-11-10 (branch `claude/m7c-damage-visuals`)

Damage-tab display revisions after the first MATLAB screenshots (D-027). No engine change.

### Added
- `src/gui/formatNumber.m`: display rounding without negative zeros.
- `src/gui/damageComparisonSummary.m`: findings text (determinate or indeterminate with degree, largest % change, largest reaction change).
- Test "Table numbers never show a negative zero, and the findings name the determinacy" (107 tests); app-check row for the findings and sub-tabs (33 rows without the in-app test run); 3 M7c mutants.

### Changed
- Damage tab: results in sub-tabs "Healthy vs damaged" (M, V, v envelopes + table + findings) and "Sensitivity along the beam"; headings and hints before the first run.
- `plotEnvelopeComparison`: healthy drawn dashed on top of the damaged curve.
- `damageComparisonTableData`, `sensitivityTableData`: use `formatNumber`; single elements shown as `8`, not `8-8`.
- `bridgeDrawing`: `EI x` label font 11.

## [0.7.1-M7b] — 2026-11-10 (branch `claude/m7b-damage-tab`)

Milestone M7b: Damage tab in the app (D-026). Source and tests were written by Claude Code.

### Added — app
- Tab "Damage (Stage 2)": damaged region (node coordinates) and loss d in %, Apply/Clear damage, drawing with the damaged run highlighted, healthy vs damaged moving-load comparison (M and v envelopes overlaid, table of extremes and reactions with signed %), sensitivity sweep with bar chart and ranking table.
- Public methods `applyDamageInputs`, `clearDamage`, `runDamageComparison`, `runDamageSensitivity`; properties `DamagedModel`, `DamageComparison`, `DamageSensitivity`.

### Added — helpers
- `src/gui/`: `damageModelFromInputs`, `damageComparisonTableData`, `sensitivityTableData`, `sensitivityQuantityCode`, `quantityDisplay`.
- `src/visualization/`: `plotEnvelopeComparison`, `plotSensitivity`; `bridgeDrawing` option `StiffnessFactor`.
- `appTheme`: colour `damage` (18 colours).

### Added — tests and tools
- 2 tests (106 in total): Damage-tab helpers in `testGuiHelpers`, damage highlight in `testDrawingGeometry`.
- `checkBridgeConditionApp`: 6 Damage-tab rows (32 in total).
- `tools/mutation_check.py`: 7 M7b mutants and an optional name-prefix filter.

## [0.7.0-M7] — 2026-11-05 (branch `claude/m7-stiffness-damage`)

Milestone M7 (Stage 2): prescribed effective-stiffness loss and healthy vs damaged comparison. Source and tests were written by Claude Code.

### Added — engine (`src/damage/`)
- `applyStiffnessDamage(model, elements, d)`: sets EI_D = (1 − d)·EI through `model.elements.stiffnessFactor`, for 0 ≤ d < 1, per element or one d for all listed elements.
- `effectiveEI(model)`: the EI the solver uses.
- `relativeChange`: the spec's signed % change; NaN for a zero healthy value.
- `compareHealthyDamaged`: moving-load comparison of envelopes, critical values with the governing x_v of each model, and reactions.
- `damageSensitivity`: moves the same loss over element groups and ranks the influence on Mmax, Mmin, Vmax, Vmin, vmax, vmin or Rmax/Rmin at a node.

### Changed — engine
- `createBeamModel`: new field `model.elements.stiffnessFactor` (all 1); `meta.formatVersion` changed from 4 to 5.
- `validateModel`: checks 0 < factor ≤ 1.
- `assembleGlobalK`, `recoverElementForces`, `evaluateDeflection`, `prepareMovingLoad` and the app's Matrices tab now use `effectiveEI`. Healthy models give identical results: all 95 earlier tests are unchanged.

### Added — tests and tools
- `tests/testStiffnessDamage.m` (9 tests):
  - d = 0 identity
  - K changes only in element j
  - simple span: forces unchanged, deflection by virtual work
  - propped cantilever: R_B and M_A by compatibility, 3 damage regions
  - two spans: M_B by the three-moment equation
  - healthy vs damaged moving-load comparison
  - fast path on a damaged model
  - sensitivity sweep
  - invalid input and material reassignment
- `tools/mutation_check.py`: 5 M7 faults added (43 in total).

### Verified
- **GNU Octave 8.4.0:** 104 of 104 tests passed; scripted app check unchanged (26/26 without the in-app test run). See VERIFICATION_LOG V-013.
- **MATLAB (recorded afterwards, V-014):** 104/104.

## [0.6.0-M6] — 2026-10-30 (branch `claude/m6-basic-gui`)

Milestone M6: basic sage-green MATLAB app over the verified engine. The code-built format was chosen by the user. Source and tests were written by Claude Code.

### Added — app and helpers
- `app/BridgeConditionApp.m`: code-built app (`uifigure`, `uigridlayout`, `uitab`, `uiaxes`, `uitable`) with five tabs:
  1. **Bridge model:** inputs, drawing with conventional supports, model summary.
  2. **Vehicle & moving load:** inputs, position slider with Start/Back/Forward, truck schematic, dashed deformed shape with its magnification, M/V/v diagrams, reactions.
  3. **Envelopes:** M/V/v envelopes, critical-position table, reaction-envelope table.
  4. **Matrices:** k_e, K, and the DOF table of status, F, U and R.
  5. **Verification:** runs `runAllTests`.
- `src/gui/`: `appTheme`, `parseNumberList`, `buildModelFromInputs`, `vehicleFromInputs`, `responseDiagramData`, `criticalTableData`, `reactionEnvelopeTableData`, `currentReactionTableData`, `dofLabels`, `formatMatrixCells`.
- `src/visualization/`:
  - `drawingPrimitive`, `supportSymbolGeometry` (pin, roller, fixed, none), `bridgeDrawing` and `drawingLimits`: drawings kept as plain data.
  - `renderDrawing`, `plotDiagram` and `plotEnvelope`: the renderers.
- `src/movingload/defaultEnvelopeStations.m` (shared by `runMovingLoad` and the app) and `modelWithVehicle.m` (the vehicle position as static point loads, for the Matrices tab).

### Changed
- `runMovingLoad`: its default stations now come from `defaultEnvelopeStations`. The behaviour is unchanged and all earlier tests pass.
- `addProjectPaths`: also adds `app/` and `tests/gui/`.

### Added — tests and tools
- `tests/testGuiHelpers.m` (9 tests) and `tests/testDrawingGeometry.m` (4 tests): 13 new main-suite tests (95 in total).
- `tests/gui/checkBridgeConditionApp.m`: scripted app check (27 checks with `true`). Runs in MATLAB on the real app, or in Octave through `tools/gui_mock/runGuiMockCheck.m`.
- `tools/gui_mock/`: Octave stand-ins for the UI components and plot functions. They check property names, layout, colours, value limits and plot/legend arguments.
- `tools/preview/`: exports the drawing primitives to JSON and renders them with matplotlib (development check).
- `tools/mutation_check.py`: 7 M6 helper faults added (38 in total).

### Added — records
- DECISIONS D-023 (GUI format and architecture) and D-024 (GUI verification without MATLAB). D-012 and D-014 updated.
- VERIFICATION_LOG V-011.

### Verified
- **GNU Octave 8.4.0:** 95 of 95 tests passed. Scripted app check against stand-in components: 27 of 27 PASS. Mutation check: all 38 real faults detected (one equivalent mutant replaced). See VERIFICATION_LOG V-011.
- **MATLAB (recorded afterwards, V-012):** runAllTests 95/95. The app check first gave 26/27, because of a check bug: MATLAB hides HandleVisibility-off objects from Children. After the fix it gives 27/27, and all 5 tabs were used.
- **Later layout fixes:** taller Vehicle-tab drawing, `fit` table columns, wider Envelopes table column.

### Known limitations
- GUI rendering, layout and appearance are unverified until the user's MATLAB run.
- There is no Play/Pause animation; use the slider and the Start/Back/Forward buttons.
- No data export from the app yet.

## [0.5.0-M5] — 2026-10-30 (branch `claude/m5-steel-rcc-materials`)

Milestone M5: steel and RCC flexural-rigidity input through the one solver. Source and tests were written by Claude Code.

### Added — engine (`src/materials/`)
- `defineMaterial.m`: steel (EI = E_s·I_s) or RCC (EI = E_c·I_eff, with I_eff supplied by the user and held constant), plus name and basis text. Warns with `BridgeFE:unusualModulus` on likely unit slips.
- `validateMaterial.m`: checks a material record, including EI = E·I.
- `assignMaterial.m`: applies a material to all or selected elements; identical records are reused.

### Changed — engine
- `createBeamModel`: accepts a material in place of EI. New fields `model.materials` and `model.elements.materialId`; `meta.formatVersion` changed from 3 to 4.
- `validateModel`: validates the material records and rejects an element whose EI differs from its material's E·I.

### Added — tests and tools (8 new tests; 82 in total)
- `tests/testMaterials.m`:
  - the material records
  - equal-EI steel/RCC/plain-EI models giving bit-identical static results
  - equal-EI models giving identical moving-load envelopes
  - a uniform EI change scaling deflections only
  - a mixed steel/RCC two-span beam against the three-moment equation with two EI values
  - the EI-edit guard and material reassignment
  - unit-sanity warnings
  - invalid input
- `tools/mutation_check.py`: 5 M5 faults added (31 in total).

### Added — records
- DECISIONS D-022 (materials). D-005 and D-012 updated.
- VERIFICATION_LOG V-009.
- Raw evidence: `results/verification/2026-10-30_M5_octave-8.4.0_runAllTests.log` and `results/verification/2026-10-30_M5_mutation_check_octave-8.4.0.txt`.

### Verified
- **GNU Octave 8.4.0:** 82 of 82 tests passed. Equal-EI steel/RCC models are bit-identical, and the mixed-material two-span beam matches the three-moment equation to 6e‑12 %. Mutation check: 31 of 31 faults detected (VERIFICATION_LOG V-009).
- **MATLAB:** M1–M4 confirmed by the user (V-002, V-004, V-006, V-008). M5 confirmed afterwards (V-010, 82/82).

### Known limitations
- No nonlinear RCC behaviour and no I_eff calculation (spec §4.4, by design).
- No material presets or I-section property calculator (optional in the spec, not added).

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

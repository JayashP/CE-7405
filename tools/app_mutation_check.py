"""App mutation check: each injected app fault must make the Octave app check (runGuiMockCheck) fail.

Usage: python3 -I tools/app_mutation_check.py <repo_root> <empty_scratch_dir> [i,j,...]
Copies the repository once per fault (without .git and results), injects one fault, runs
tools/gui_mock/runGuiMockCheck in GNU Octave (3 at a time) and prints one JSON line per fault
with the first FAIL row or error. Never modifies <repo_root>. M9: faults 0-30, M9c: 31-40, M10: 41-60; see
results/verification/2026-11-19_M9_mutation_check_octave-8.4.0.txt.
"""
import shutil, subprocess, sys, pathlib, json
from concurrent.futures import ThreadPoolExecutor
repo = pathlib.Path(sys.argv[1]).resolve()
work = pathlib.Path(sys.argv[2]).resolve()
A = 'app/BridgeConditionApp.m'
M = [
 ('slider released: value not converted to m', A, "app.setVehiclePosition(src.Value * app.Units.length.toSI)", "app.setVehiclePosition(src.Value)"),
 ('slider dragged: value not converted to m', A, "app.setVehiclePosition(event.Value * app.Units.length.toSI)", "app.setVehiclePosition(event.Value)"),
 ('reaction envelope table without units', A, "reactionEnvelopeTableData(ml, app.Model.nodes.x, U)", "reactionEnvelopeTableData(ml, app.Model.nodes.x)"),
 ('Rmax support drop-down mapped by list position', A, "findNodeAtX(app.Model, info.supportX(k)), supported);", "findNodeAtX(app.Model, info.supportX(k)), 1:numel(supported));"),
 ('hidden region start read from the damage drop-down', A, "app.selectedNodeX(c.HiddenFromDropDown), app.selectedNodeX(c.HiddenToDropDown)", "app.selectedNodeX(c.DamageFromDropDown), app.selectedNodeX(c.HiddenToDropDown)"),
 ('default sensors written in m', A, "app.setPointTable(c.SensorsTable, sensors / app.Units.length.toSI, 'S');", "app.setPointTable(c.SensorsTable, sensors, 'S');"),
 ('default truck positions written in m', A, "app.setPointTable(c.PositionsTable, positions / app.Units.length.toSI, 'P');", "app.setPointTable(c.PositionsTable, positions, 'P');"),
 ('sweep step not converted on a switch', A, "'step', 'length', 'sensitivityStep', 'length', ...", "'step', 'length', ..."),
 ('reading noise not converted on a switch', A, "                'noiseAbs', 'deflection', 'sensors'", "                'sensors'"),
 ('position text x_v in m', A, "xv / U.length.toSI, U.length.unit, nnz(res.axles.onBridge)", "xv, U.length.unit, nnz(res.axles.onBridge)"),
 ('M, V, v diagrams drawn at x in m', A, "x = d.x / U.length.toSI;", "x = d.x;"),
 ('envelopes drawn at x in m', A, "x = ml.stations / U.length.toSI;", "x = ml.stations;"),
 ('new axle 1.2 display units behind', A, "[spacings, 1.2 / app.Units.length.toSI]", "[spacings, 1.2]"),
 ('identification options without the units', A, "c.SearchNoiseAbsField.Value, app.Direction, app.Units);", "c.SearchNoiseAbsField.Value, app.Direction);"),
 ('presets always in SI', A, "presets = vehiclePresets(app.Units);\n            p = presets(", "presets = vehiclePresets(unitSystem('SI'));\n            p = presets("),
 ('supports table x converted twice', A, "xs = [0, cumsum(lengths)];", "xs = [0, cumsum(lengths)] * U.length.toSI;"),
 ('fix: invalid input not checked before a switch', A, "                app.checkModelAndVehicleInputs(old);\n", ""),
 ('fix: refused switch leaves the new units in the drop-down', A, "                c.UnitsDropDown.Value = old.label;\n", ""),
 ('fix: readings tab title not relabelled', A, "            c.IdentReadingsTab.Title = sprintf('Readings [%s]', U.deflection.unit);\n", ""),
 ('fix: a switch swaps the material default E again', A, "            app.updateInertiaLabel();\n            c.UDLLabel.Text", "            app.onMaterialChanged();\n            c.UDLLabel.Text"),
 ('fix: memory dropped when a row was added', A, "m = min(numel(v), numel(shown));", "m = min(numel(v), numel(shown)) * isequal(size(v), size(shown));"),
 ('fix: emptied critical table keeps its old header', A, "            c.CriticalTable.ColumnName = {};            % headers (with units) come with the results\n", ""),
 ('fix: emptied candidate table keeps its old header', A, "            c.CandidateTable.ColumnName = {};           % headers (with units) come with the results\n", ""),
 ('fix: noise tooltip not relabelled', A, "            c.SearchNoiseField.Tooltip = app.noiseTooltip();\n", ""),
 ('fix: sensor end tolerance back to 1e-9 L', A, "tol = 1e-5 * (x(end) - x(1));", "tol = 1e-9 * (x(end) - x(1));"),
 ('fix: sensors at the end not clamped', A, "            sensors = min(max(sensors, x(1)), x(end));\n", ""),
 ('fix: app reads numeric text in table cells', A, "                if isnumeric(x) && isscalar(x) && isreal(x) && isfinite(x)\n", "                if ischar(x), x = str2double(x); end\n                if isnumeric(x) && isscalar(x)\n"),
 ('fix: modelling notes left out of the summary', 'src/gui/infoPanelHtml.m', "'Linear, quasi-static analysis. Not a load rating or design check.'}, 'note');", "'Linear, quasi-static analysis.'}, 'note');"),
 ('fix: E/I fields keep the 4-digit display', A, "'Value', 200, 'Limits', [0 Inf], 'LowerLimitInclusive', 'off', 'ValueDisplayFormat', '%.6g', ...", "'Value', 200, 'Limits', [0 Inf], 'LowerLimitInclusive', 'off', ..."),
 ('sweep: Back button throws', A, "'ButtonPushedFcn', @(~, ~) app.stepVehicle(-1));", "'ButtonPushedFcn', @(~, ~) app.stepVehicle(-1, 2));"),
 ('sweep: Apply model reports an error (span 1 = -1 before the sweep)', 'tests/gui/checkBridgeConditionApp.m', "comps = collectComponents(app.UIFigure);", "c.SpansTable.Data{1, 1} = -1;\ncomps = collectComponents(app.UIFigure);"),
 # M9c (cosmetic follow-ups from the MATLAB screenshots, V-026 part 2a)
 ('M9c: slider keeps the automatic ticks (limit labelled)', A, "            s.MajorTicks = app.sliderTicks(s.Limits);   % round values; the crossing end is not labelled\n", ""),
 ('M9c: slider ticks too coarse', A, "raw = (limits(2) - limits(1)) / 10;", "raw = (limits(2) - limits(1)) / 3;"),
 ('M9c: no status after a preset is chosen', A, "            c.VehicleNameField.Value = p.name;\n            app.setStatus(app.vehicleEditedText());\n", "            c.VehicleNameField.Value = p.name;\n"),
 ('M9c: no status after an axle edit', A, "            app.updateAxleTotal();\n            app.setStatus(app.vehicleEditedText());\n", "            app.updateAxleTotal();\n"),
 ('M9c: no status after Apply vehicle', A, "            if ok && isempty(app.LastError)", "            if false"),
 ('M9c: ticks neither clamped nor -0 removed', A, "            ticks = min(max(ticks, limits(1)), limits(2)) + 0;   % no tick 1e-14 outside; -0 becomes 0\n", ""),
 ('M9c: no status after a direction edit', A, "'Value', app.DirectionItems{1}, 'ValueChangedFcn', edited));", "'Value', app.DirectionItems{1}));"),
 ('M9c: no status after a position-step edit', A, "'ValueDisplayFormat', '%.6g', 'ValueChangedFcn', edited));", "'ValueDisplayFormat', '%.6g'));"),
 ('M9c: drawing labels not clipped (app check)', 'src/visualization/renderDrawing.m', "'Interpreter', 'none', ...\n                'Clipping', 'on');", "'Interpreter', 'none');"),
 ('M9c: reaction headers keep the sign rule', A, "c.ReactionsTable.ColumnName = regexprep(columns, ' \\(\\+ (up|CCW)\\)$', '');", "c.ReactionsTable.ColumnName = columns;"),
 # M10 (GUI clarity: legends, sensor/position tables, formatted boxes, colours, 9 fixes)
 ('M10: x_v not explained under the critical table', A, "x_v = position of the truck''s front ' ...", "x_v = the truck ' ..."),
 ('M10: slider readout without "measured from A"', A, "(front axle, measured from A); %d of %d", "(front axle); %d of %d"),
 ('M10: + Add repeats the last value', A, "next = 2 * v(end) - v(end - 1);", "next = v(end);"),
 ('M10: + Add not capped at the end of the range', A, "next = min(max(next, limits(1)), limits(2));", "next = max(next, limits(1));"),
 ('M10: - Remove empties the table', A, "            if numel(v) < 2\n                app.setStatus(sprintf('At least one %s is needed.', noun));", "            if numel(v) < 1\n                app.setStatus(sprintf('At least one %s is needed.', noun));"),
 ('M10: off-beam sensor not checked', A, "off = find(sensors < x(1) - tol | sensors > x(end) + tol, 1);", "off = [];"),
 ('M10: a unit switch resets your sensors', A, "                app.setPointTable(c.SensorsTable, after.sensors, 'S');\n", ""),
 ('M10: sensors not converted on a switch', A, "'sensors', 'length', 'positions', 'length'", "'positions', 'length'"),
 ('M10: region order message left to the engine (m)', A, "                app.checkRegionOrder(c.DamageFromDropDown, c.DamageToDropDown, 'Damaged region');\n", ""),
 ('M10: node numbers replace the preview', A, "            if app.Previewing\n                app.previewModel();", "            if false\n                app.previewModel();"),
 ('M10: E edit gives no preview', A, "'Value', 200, 'Limits', [0 Inf], 'LowerLimitInclusive', 'off', 'ValueDisplayFormat', '%.6g', ...\n                'ValueChangedFcn', @(~, ~) app.previewModel()));", "'Value', 200, 'Limits', [0 Inf], 'LowerLimitInclusive', 'off', 'ValueDisplayFormat', '%.6g'));"),
 ('M10: + Add span leaves the far-end type behind', A, "            data(end-1:end, 3) = {'Roller'; farEnd};     % the old end becomes an interior roller\n", ""),
 ('M10: - Remove span loses the far-end type', A, "            c.SupportsTable.Data{end, 3} = farEnd;       % keep the far-end support type (e.g. a Fixed end)\n", ""),
 ('M10: sensitivity names a most influential element on ties', A, "            if max(abs(s.change)) <= 1e-9 * max(abs([s.healthy; s.values(:)]))", "            if false"),
 ('M10: hidden loss allowed beyond the search range', A, "'Limits', [0 60], 'Tooltip', 'The search covers", "'Limits', [0 99], 'Tooltip', 'The search covers"),
 ('M10: model summary unformatted', A, "            c.SummaryArea.HTMLSource = infoPanelHtml('model', info.summary);\n            app.Previewing = false;", "            c.SummaryArea.HTMLSource = infoPanelHtml('message', info.summary);\n            app.Previewing = false;"),
 ('M10: findings unformatted', A, "infoPanelHtml('findings', damageComparisonSummary(cmp, app.Model, U));", "infoPanelHtml('message', damageComparisonSummary(cmp, app.Model, U));"),
 ('M10: left box drops the flags', A, "infoPanelHtml('identBox', [summary(2); flags; {", "infoPanelHtml('identBox', [summary(2); {"),
 ('M10: healthy max and min in one colour', A, "healthy = [th.healthyMax; th.healthyMin];", "healthy = [th.healthyMax; th.healthyMax];"),
 ('M10: unit-slip message range always in GPa', 'src/gui/buildModelFromTables.m', "range = materialModulusRange(in.materialType) / U.modulus.toSI;", "range = materialModulusRange(in.materialType) / 1e9;"),
]
src = (repo / A).read_text()
for name, f, old, new in M:
    t = (repo / f).read_text()
    assert t.count(old) == 1, (name, t.count(old))
def run(i):
    name, f, old, new = M[i]
    d = work / f'mut{i:02d}'
    if d.exists(): shutil.rmtree(d)
    shutil.copytree(repo, d, ignore=shutil.ignore_patterns('.git', 'results'))
    p = d / f
    p.write_text(p.read_text().replace(old, new))
    r = subprocess.run(['timeout', '1500', 'octave-cli', '--no-gui', '--norc', '--eval',
                        "addpath('tools/gui_mock'); runGuiMockCheck"], cwd=d, capture_output=True, text=True)
    out = r.stdout + r.stderr
    fails = [l.strip()[:110] for l in out.splitlines() if l.rstrip().endswith('FAIL')]
    errs = [l.strip()[:150] for l in out.splitlines() if l.startswith('error:')][:2]
    res = {'i': i, 'name': name, 'exit': r.returncode, 'detected': r.returncode != 0, 'fails': fails, 'errors': errs}
    (work / f'mut{i:02d}.log').write_text(out)
    shutil.rmtree(d)
    print(json.dumps(res), flush=True)
    return res
only = [int(x) for x in sys.argv[3].split(',')] if len(sys.argv) > 3 else range(len(M))
with ThreadPoolExecutor(max_workers=3) as ex:
    results = list(ex.map(run, only))
print('SUMMARY', sum(r['detected'] for r in results), '/', len(results), 'detected')
for r in results:
    if not r['detected']: print('SURVIVED', r['i'], r['name'])

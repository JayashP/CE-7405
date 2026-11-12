function rows = checkBridgeConditionApp(includeVerification)
%CHECKBRIDGECONDITIONAPP Drive BridgeConditionApp and compare it with direct engine calls.
%   ROWS = CHECKBRIDGECONDITIONAPP() opens the app and works through it like
%   a user would. It checks the model tab, a vehicle position, stepping,
%   the envelopes, the matrices, the travel direction, invalid input, a unit
%   slip, and every button and value callback. Wherever possible, what the
%   app holds and shows is compared with the same quantities computed
%   directly by the verified engine. It prints a PASS/FAIL table, closes the
%   app, and throws 'BridgeFE:test:referenceMismatch' if any check fails.
%   CHECKBRIDGECONDITIONAPP(true) also presses "Run all tests" on the
%   Verification tab, which runs the whole suite inside the app (slower).
%
%   MATLAB (needs a display):   addProjectPaths; checkBridgeConditionApp
%   GNU Octave (no App Designer): runs against the stand-in components in
%   tools/gui_mock, see tools/gui_mock/runGuiMockCheck.m.
%
%   See also BRIDGECONDITIONAPP.

if nargin < 1
    includeVerification = false;
end
app = BridgeConditionApp();
closer = onCleanup(@() delete(app));
c = app.Controls;
truckName = 'Illustrative 3-axle truck';
refVehicle = vehicleFromInputs('80 120 120', '4.2 1.4', truckName);

% 1. Start-up state equals the engine
in = struct('spans', '20', 'elementsPerSpan', 16, 'supports', 'pin roller', 'materialType', 'steel', ...
    'E_GPa', 200, 'I_m4', 0.01, 'materialName', '', 'materialBasis', '', 'udlDown_kNpm', 0);
rows = flag('start-up model = buildModelFromInputs(default inputs)', isequal(app.Model, buildModelFromInputs(in)));
rows(end+1) = flag('start-up vehicle = vehicleFromInputs(default inputs)', isequal(app.Vehicle, refVehicle));
rows(end+1) = flag('start-up position is the crossing start, x_v = 0', app.Position == 0);
rows(end+1) = flag('model tab drawing has > 10 graphics objects', numel(c.ModelAxes.Children) > 10);

% 2. Two-span RCC model with a permanent uniform load, entered through the inputs
c.SpansField.Value = '12 15';
c.ElementsField.Value = 8;
c.SupportsField.Value = 'pin roller roller';
c.MaterialDropDown.Value = 'RCC';
c.EField.Value = 32;
c.IField.Value = 0.0625;
c.UDLField.Value = 10;
ok = app.applyModelInputs();
in = struct('spans', '12 15', 'elementsPerSpan', 8, 'supports', 'pin roller roller', 'materialType', 'rcc', ...
    'E_GPa', 32, 'I_m4', 0.0625, 'materialName', '', 'materialBasis', '', 'udlDown_kNpm', 10);
refModel = buildModelFromInputs(in);
rows(end+1) = flag('Apply model with 2 spans, RCC, 10 kN/m succeeds', ok && isempty(app.LastError));
rows(end+1) = flag('app model = buildModelFromInputs(the same inputs)', isequal(app.Model, refModel));
rows(end+1) = flag('model summary text is shown', numel(c.SummaryArea.Value) >= 5);
prep = prepareMovingLoad(refModel, defaultEnvelopeStations(refModel.nodes.x, 4));

% 3. A vehicle position equals the engine's result
app.setVehiclePosition(16.4);
ref = analyzeVehiclePosition(prep, refVehicle, 16.4, 1);
rows(end+1) = compareToReference('x_v = 16.4 m: max|U_app - U_engine| / max|U| [-]', ...
    max(abs(app.PositionResult.U - ref.U)) / max(abs(ref.U)), 0, [], 1e-12);
rows(end+1) = compareToReference('x_v = 16.4 m: max|R_app - R_engine| / max|R| [-]', ...
    max(abs(app.PositionResult.R - ref.R)) / max(abs(ref.R)), 0, [], 1e-12);
B = findNodeAtX(refModel, 12);
rows(end+1) = flag('reaction table shows 3 supports and R_B of the engine', size(c.ReactionsTable.Data, 1) == 3 ...
    && strcmp(c.ReactionsTable.Data{2, 4}, sprintf('%.3f', ref.R(2*B - 1) / 1e3)));
rows(end+1) = flag('beam, M, V and v axes are drawn', numel(c.BeamAxes.Children) > 20 && numel(c.MomentAxes.Children) >= 3 ...
    && numel(c.ShearAxes.Children) >= 3 && numel(c.DeflectionAxes.Children) >= 3);
app.stepVehicle(1);
rows(end+1) = compareToReference('Forward moves x_v by one step [m]', app.Position - 16.4, app.Step, 1e-9);

% 4. Envelopes equal runMovingLoad
ok = app.runEnvelopes();
refML = runMovingLoad(refModel, refVehicle, 'Step', app.Step, 'Direction', 1);
rows(end+1) = flag('Run moving-load analysis succeeds', ok);
rows(end+1) = flag('app envelopes = runMovingLoad envelopes', isequal(app.MovingLoad.envelope, refML.envelope));
rows(end+1) = flag('app critical values = runMovingLoad critical values', ...
    isequal([app.MovingLoad.critical.value], [refML.critical.value]));
rows(end+1) = flag('critical table 6 x 7, reaction envelope table 3 rows', isequal(size(c.CriticalTable.Data), [6 7]) ...
    && size(c.EnvReactionsTable.Data, 1) == 3);
% The band, zero line and markers have HandleVisibility 'off' (kept out of the
% legend), and MATLAB leaves such objects out of Children: count the 2 curves.
rows(end+1) = flag('M, V and v envelope axes show the max and min curves', numel(c.EnvMomentAxes.Children) >= 2 ...
    && numel(c.EnvShearAxes.Children) >= 2 && numel(c.EnvDeflectionAxes.Children) >= 2);

% 5. Matrices tab equals the static solution at the current position
ok = app.showMatrices();
st = solveStaticModel(modelWithVehicle(refModel, refVehicle, app.Position, 1));
nDof = 2 * numel(refModel.nodes.x);
rows(end+1) = flag('Matrices tab fills', ok);
rows(end+1) = compareToReference('Matrices tab: max|U_app - U_static| / max|U| [-]', ...
    max(abs(app.StaticResult.U - st.U)) / max(abs(st.U)), 0, [], 1e-12);
rows(end+1) = flag('k_e table 4 x 4, K table nDof x nDof, DOF table nDof rows', isequal(size(c.KeTable.Data), [4 4]) ...
    && isequal(size(c.KTable.Data), [nDof nDof]) && size(c.DofTable.Data, 1) == nDof);
rows(end+1) = flag('K(1,1) shown as the engine value', strcmp(c.KTable.Data{1, 1}, sprintf('%.4g', full(st.K(1, 1)))));

% 6. Travel toward -x starts at the right end
c.DirectionDropDown.Value = '-x (right to left)';
ok = app.applyVehicleInputs();
rows(end+1) = flag('direction -x: Direction = -1 and x_v starts at the right end (27 m)', ok && app.Direction == -1 ...
    && abs(app.Position - 27) < 1e-12);
c.DirectionDropDown.Value = '+x (left to right)';
app.applyVehicleInputs();

% 7. Invalid input is reported and the previous model is kept
before = app.Model;
c.SupportsField.Value = 'pin roller';
ok = app.applyModelInputs();
rows(end+1) = flag('2 support entries for 3 span ends: rejected, message shown, model kept', ~ok ...
    && ~isempty(strfind(app.LastError, 'span ends')) && isequal(app.Model, before));
c.SupportsField.Value = 'pin roller roller';
c.AxleLoadsField.Value = '80 abc';
ok = app.applyVehicleInputs();
rows(end+1) = flag('axle loads ''80 abc'': rejected with a message naming ''abc''', ~ok && ~isempty(strfind(app.LastError, 'abc')));
c.AxleLoadsField.Value = '80 120 120';
app.applyVehicleInputs();

% 8. A unit slip is warned about
c.EField.Value = 32e9;                    % Pa typed into the GPa field
ok = app.applyModelInputs();
rows(end+1) = flag('E = 32e9 "GPa": model built and a unit warning reported', ok && numel(app.ModelInfo.warnings) == 1);
c.EField.Value = 32;
app.applyModelInputs();

% 9. Damage tab (Stage 2) equals applyStiffnessDamage, compareHealthyDamaged and damageSensitivity
c.DamageFromField.Value = 9;              % nodes of the 12 m + 15 m model (1.5 m and 1.875 m elements)
c.DamageToField.Value = 13.875;
c.LossField.Value = 40;
ok = app.applyDamageInputs();
refDamaged = applyStiffnessDamage(refModel, elementsBetween(refModel, 9, 13.875), 0.40);
rows(end+1) = flag('Apply damage 9-13.875 m, d = 40 %: app model = applyStiffnessDamage(...)', ok ...
    && isequal(app.DamagedModel, refDamaged) && isequal(app.Model, refModel));
rows(end+1) = flag('damage drawing has the highlight (more objects than the healthy drawing)', ...
    numel(c.DamageAxes.Children) > numel(c.ModelAxes.Children));
ok = app.runDamageComparison();
refCmp = compareHealthyDamaged(refModel, refDamaged, refVehicle, 'Step', app.Step, 'Direction', 1);
rows(end+1) = flag('Compare: app result = compareHealthyDamaged(...)', ok ...
    && isequal([app.DamageComparison.critical.damaged], [refCmp.critical.damaged]) ...
    && isequal(app.DamageComparison.damaged.envelope, refCmp.damaged.envelope));
rows(end+1) = flag('comparison table 6 + 2 x 3 reaction rows; M, V and v axes show 4 curves', ...
    size(c.DamageTable.Data, 1) == 12 && numel(c.DamageMomentAxes.Children) >= 4 ...
    && numel(c.DamageShearAxes.Children) >= 4 && numel(c.DamageDeflectionAxes.Children) >= 4);
rows(end+1) = flag('findings = damageComparisonSummary (indeterminate, degree 1); results sub-tab shown', ...
    isequal(c.DamageFindings.Value, damageComparisonSummary(refCmp, refModel)) ...
    && ~isempty(strfind(c.DamageFindings.Value{1}, 'degree 1')) && strcmp(c.DamageResultTabs.SelectedTab.Title, c.DamageCompareTab.Title));
c.SensitivityDropDown.Value = c.SensitivityDropDown.Items{1};   % largest downward deflection
ok = app.runDamageSensitivity();
refSens = damageSensitivity(refModel, refVehicle, 0.40, 'vmin', 'Step', max(app.Step, 0.5), 'Direction', 1, ...
    'Refine', false);
rows(end+1) = flag('Sensitivity (vmin): app result = damageSensitivity(...)', ok ...
    && isequal(app.DamageSensitivity.change, refSens.change) && size(c.SensitivityTable.Data, 1) == numel(refSens.groups) ...
    && strcmp(c.DamageResultTabs.SelectedTab.Title, c.DamageSensitivityTab.Title));
app.clearDamage();
rows(end+1) = flag('Clear damage: no damaged model, tables emptied, healthy model unchanged', ...
    isempty(app.DamagedModel) && isempty(c.DamageTable.Data) && isequal(app.Model, refModel));
app.applyDamageInputs();                  % leave a valid damage for the callback sweep

% 10. Identification tab (Stage 3) equals syntheticObservations and identifySingleDamage
[sRef, pRef] = identificationDefaults(refModel, refVehicle, 1);
rows(end+1) = flag('Stage 3 defaults: sensors L/4, L/2, 3L/4; positions L/4..L (5L/4 has no axle on the 27 m beam)', ...
    isequal(pRef, [6.75 13.5 20.25 27]) && ...
    strcmp(c.SensorField.Value, numberListText(sRef)) && strcmp(c.IdentPositionsField.Value, numberListText(pRef)));
c.HiddenFromField.Value = 9;              % node coordinates of the 12 m + 15 m model
c.HiddenToField.Value = 10.5;
c.HiddenLossField.Value = 30;
c.SyntheticNoiseField.Value = 1;
c.SeedField.Value = 3;
ok = app.generateSyntheticReadings();
[uRef, truthRef] = syntheticObservations(refModel, refVehicle, pRef, sRef, 1, 9, 10.5, 30, 1, 3);
rows(end+1) = flag('Generate: readings table = 1000 x syntheticObservations(...) [mm]; hidden case kept apart', ok ...
    && isequal(c.ReadingsTable.Data, 1e3 * uRef) && isequal(app.IdentTruth, truthRef) && isempty(app.IdentResult));
c.SearchNoiseField.Value = 1;
c.SearchNoiseAbsField.Value = 0;
c.RegionSizeDropDown.Value = 'Each element';
ok = app.runIdentification();
opts = identificationOptions(refModel, 0, 1, 0, 1);
ref = identifySingleDamage(refModel, refVehicle, pRef, sRef, c.ReadingsTable.Data / 1e3, opts{:});
rows(end+1) = flag('Run: app result = identifySingleDamage(...) (best, region, fit check)', ok ...
    && isequal(app.IdentResult.best.elements, ref.best.elements) && app.IdentResult.best.d == ref.best.d ...
    && isequal([app.IdentResult.competing.group], [ref.competing.group]) ...
    && isequal(app.IdentResult.uncertaintyRegions, ref.uncertaintyRegions) && app.IdentResult.gof.S == ref.gof.S);
[refData, ~] = identificationTableData(ref);
pf = fitProfileData(ref, refModel);
cap = 4 * pf.threshold;                   % bars above 4 x the limit are cut and marked (plotFitProfile)
nFit = numel(pf.value) + nnz(pf.value > cap) + 1 + (pf.healthyValue <= cap);
rows(end+1) = flag('candidate table and summary text show that result; fit sub-tab selected', ...
    isequal(c.CandidateTable.Data, refData) && isequal(c.IdentInfo.Value, identificationSummary(ref, truthRef)) ...
    && strcmp(c.IdentResultTabs.SelectedTab.Title, 'Fit by location'));
rows(end+1) = flag('fit chart: one bar per candidate, cut-off markers, limit and no-damage lines; legend', ...
    numel(c.FitAxes.Children) == nFit && any(strcmp(c.FitAxes.Legend, 'limit')));
rows(end+1) = flag('readings plot: 4 objects per sensor (healthy, best fit, readings, label); 3 legend entries', ...
    numel(c.ReadingsAxes.Children) == 4 * numel(sRef) && isequal(c.ReadingsAxes.Legend, {'healthy model', 'best fit', 'readings'}));
expected = bridgeDrawing(refModel, struct('SymbolSize', 0.04 * 27, 'Theme', appTheme(), 'Sensors', sRef, ...
    'Regions', ref.uncertaintyRegions, 'BestRegion', ref.best.x, 'BestLabel', ...
    sprintf('best fit: d = %s %%', formatNumber(100 * ref.best.d, 1)), 'TrueRegion', truthRef.x));
rows(end+1) = flag('drawing = bridgeDrawing with sensors, region, best fit and hidden case (object by object)', ...
    numel(c.IdentAxes.Children) == numel(expected));
c.RegionSizeDropDown.Value = '2 m regions';
ok = app.runIdentification();
rows(end+1) = flag('2 m candidate regions: groups = candidateGroups(model, 2)', ok ...
    && isequal(app.IdentResult.groups, candidateGroups(refModel, 2)));
c.RegionSizeDropDown.Value = 'Each element';
c.SensorField.Value = '5 10';
ok = app.runIdentification();
rows(end+1) = flag('sensors changed after the readings: run refused with a message', ~ok ...
    && ~isempty(strfind(app.LastError, 'readings table')));
c.SensorField.Value = numberListText(sRef);
c.DirectionDropDown.Value = '-x (right to left)';
app.applyVehicleInputs();
[sNeg, pNeg] = identificationDefaults(refModel, refVehicle, -1);
okGen = app.generateSyntheticReadings();
uNeg = syntheticObservations(refModel, refVehicle, pNeg, sNeg, -1, 9, 10.5, 30, 1, 3);
okRun = app.runIdentification();
optsNeg = identificationOptions(refModel, 0, 1, 0, -1);
refNeg = identifySingleDamage(refModel, refVehicle, pNeg, sNeg, uNeg, optsNeg{:});
rows(end+1) = flag('-x travel: mirrored positions, readings and result = direct calls with direction -1', okGen && okRun ...
    && strcmp(c.IdentPositionsField.Value, numberListText(pNeg)) && isequal(c.ReadingsTable.Data, 1e3 * uNeg) ...
    && isequal([app.IdentResult.competing.group], [refNeg.competing.group]) && app.IdentResult.best.d == refNeg.best.d);
c.DirectionDropDown.Value = '+x (left to right)';
app.applyVehicleInputs();
app.generateSyntheticReadings();

% 11. Every button and value callback runs without error
comps = collectComponents(app.UIFigure);
nCalls = 0;
failures = {};
for k = 1:numel(comps)
    h = comps{k};
    calls = {};
    if isprop(h, 'ButtonPushedFcn') && ~isempty(h.ButtonPushedFcn) ...
            && (includeVerification || isempty(strfind(h.Text, 'Run all tests')))
        calls{end+1} = {h.ButtonPushedFcn, []}; %#ok<AGROW>
    end
    if isprop(h, 'ValueChangedFcn') && ~isempty(h.ValueChangedFcn)
        calls{end+1} = {h.ValueChangedFcn, struct('Value', h.Value, 'PreviousValue', h.Value)}; %#ok<AGROW>
    end
    if isprop(h, 'ValueChangingFcn') && ~isempty(h.ValueChangingFcn)
        calls{end+1} = {h.ValueChangingFcn, struct('Value', h.Value)}; %#ok<AGROW>
    end
    if isprop(h, 'SelectionChangedFcn') && ~isempty(h.SelectionChangedFcn)
        tabs = h.Children;
        for t = 1:numel(tabs)
            if iscell(tabs)
                tab = tabs{t};
            else
                tab = tabs(t);
            end
            calls{end+1} = {h.SelectionChangedFcn, struct('NewValue', tab, 'OldValue', tab)}; %#ok<AGROW>
        end
    end
    for j = 1:numel(calls)
        nCalls = nCalls + 1;
        try
            feval(calls{j}{1}, h, calls{j}{2});
        catch err
            failures{end+1} = err.message; %#ok<AGROW>
        end
    end
end
if ~isempty(failures)
    fprintf('  callback errors:\n');
    fprintf('    %s\n', failures{:});
end
rows(end+1) = flag(sprintf('%d callbacks invoked (buttons, fields, slider, tabs) without error', nCalls), ...
    isempty(failures) && nCalls >= 15 && isempty(app.LastError));

% 12. Verification tab (optional, runs the whole suite)
if includeVerification
    out = app.runVerification();
    rows(end+1) = flag('Verification tab: test suite reports 0 failed', ~isempty(regexp(out, 'Total: \d+ passed, 0 failed', 'once')));
end

reportComparisons('BridgeConditionApp driven through its inputs vs direct engine calls', rows);
if nargout == 0
    clear rows   % no 'ans = 1x43 struct array' echo when called as a command
end
end

function row = flag(name, condition)
row = compareToReference([name ' (1 = yes)'], double(logical(condition)), 1, 1e-9);
end

function list = collectComponents(h)
list = {h};
if isprop(h, 'Children')
    children = h.Children;
    for k = 1:numel(children)
        if iscell(children)
            child = children{k};
        else
            child = children(k);
        end
        list = [list, collectComponents(child)]; %#ok<AGROW>
    end
end
end

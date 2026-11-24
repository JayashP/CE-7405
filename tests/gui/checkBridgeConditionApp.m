function rows = checkBridgeConditionApp(includeVerification)
%CHECKBRIDGECONDITIONAPP Drive BridgeConditionApp and compare it with direct engine calls.
%   ROWS = CHECKBRIDGECONDITIONAPP() opens the app and works through it like
%   a user would. It checks the span and support tables (with their + and -
%   buttons), a vehicle position, stepping, the envelopes, the matrices, the
%   travel direction, invalid input, a unit slip, the Damage and
%   Identification tabs (node drop-downs), the vehicle presets and axle
%   table, the SI / US unit switch, and every button, value and cell-edit
%   callback. Wherever possible, what the app holds and shows is compared
%   with the same quantities computed directly by the verified engine. It
%   prints a PASS/FAIL table, closes the app, and throws
%   'BridgeFE:test:referenceMismatch' if any check fails.
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
% The check's two-span bridge is RCC, so every identification run issues the spec section 7 caveat
% 'BridgeFE:rccInverse'. It is expected here and is checked in a row (result flag and the text in the
% app), so it is not printed many times. The deliberate unit slip of section 8 is reported by the app in
% its own message (in GPa), so no warning is printed for it.
rccWarning = warning('off', 'BridgeFE:rccInverse');
restoreRccWarning = onCleanup(@() warning(rccWarning));
c = app.Controls;
SI = unitSystem('SI');
US = unitSystem('US');
presets = vehiclePresets(SI);
truckName = presets(1).name;
refVehicle = vehicleFromInputs('80 120 120', '4.2 1.4', truckName);

% 1. Start-up state equals the engine
in = struct('spans', '20', 'elementsPerSpan', 16, 'supports', 'pin roller', 'materialType', 'steel', ...
    'E_GPa', 200, 'I_m4', 0.01, 'materialName', '', 'materialBasis', '', 'udlDown_kNpm', 0);
startModel = buildModelFromInputs(in);
rows = flag('start-up model = buildModelFromInputs(20 m, 16 elements, pin roller, steel 200 GPa, 0.01 m^4)', ...
    isequal(app.Model, startModel));
rows(end+1) = flag('start-up vehicle = first preset = vehicleFromInputs(''80 120 120'', ''4.2 1.4'')', ...
    strcmp(truckName, 'Illustrative 3-axle truck (spec)') && isequal(app.Vehicle, refVehicle));
rows(end+1) = flag('start-up: SI units; supports table A (0 m, Pin), B (20 m, Roller)', strcmp(app.Units.name, 'SI') ...
    && strcmp(c.UnitsDropDown.Value, SI.label) && isequal(c.SupportsTable.Data, {'A', 0, 'Pin'; 'B', 20, 'Roller'}));
rows(end+1) = flag('start-up position is the crossing start, x_v = 0', app.Position == 0);
rows(end+1) = flag('model tab drawing has > 10 graphics objects', numel(c.ModelAxes.Children) > 10);
sensItems = c.SensitivityDropDown.Items;
sensCodes = cellfun(@sensitivityQuantityCode, sensItems, 'UniformOutput', false);
c.SensitivityDropDown.Value = sensItems{strcmp(sensCodes, 'Mmin')};   % hogging moment of a simple span: zero
okZero = app.runDamageSensitivity();
rows(end+1) = flag(['simple span, hogging-moment sensitivity: the status says the response is zero everywhere ' ...
    '(no "most influential" element) and the % column is n/a, not round-off percentages'], okZero ...
    && ~isempty(strfind(c.StatusLabel.Text, 'the response is zero for every location')) ...
    && all(strcmp(c.SensitivityTable.Data(:, end), 'n/a')));
c.SensitivityDropDown.Value = sensItems{1};

% 2. Span table: + and - buttons; the supports table follows the span ends
app.addSpan();
rows(end+1) = flag('+ Add span: 2 spans of 20 m; supports A, B, C at 0, 20, 40 m (the new end a roller)', ...
    isequal(c.SpansTable.Data, {20, 16; 20, 16}) ...
    && isequal(c.SupportsTable.Data, {'A', 0, 'Pin'; 'B', 20, 'Roller'; 'C', 40, 'Roller'}));
c.SupportsTable.Data{3, 3} = 'Free';      % an overhang at C: - Remove last span must not move "Free" onto B
app.removeSpan();
typesNoTip = c.SupportsTable.Data(:, 3)';
app.addSpan();
rows(end+1) = flag('- Remove last span of a Pin-Roller-Free overhang gives Pin-Roller (the free tip is not moved onto B)', ...
    isequal(typesNoTip, {'Pin', 'Roller'}) && isequal(c.SupportsTable.Data(:, 3)', {'Pin', 'Roller', 'Roller'}));
c.SupportsTable.Data{3, 3} = 'Fixed';
app.addSpan();
typesAdded = c.SupportsTable.Data(:, 3)';
app.removeSpan();
rows(end+1) = flag(['+ then - : the far-end type (C Fixed) moves to the new end D (C becomes a roller) and back to C; ' ...
    'model not applied yet'], isequal(typesAdded, {'Pin', 'Roller', 'Roller', 'Fixed'}) ...
    && size(c.SpansTable.Data, 1) == 2 && isequal(c.SupportsTable.Data(:, 3)', {'Pin', 'Roller', 'Fixed'}) ...
    && isequal(app.Model, startModel));
% Two-span RCC model with a permanent uniform load, typed into the tables and fields
c.SpansTable.Data = {12, 8; 15, 8};
app.onSpansEdited();                      % what the span table's cell-edit callback does
c.SupportsTable.Data{3, 3} = 'Roller';
c.MaterialDropDown.Value = 'RCC';
c.EField.Value = 32;
c.IField.Value = 0.0625;
c.UDLField.Value = 10;
ok = app.applyModelInputs();
in = struct('spans', '12 15', 'elementsPerSpan', 8, 'supports', 'pin roller roller', 'materialType', 'rcc', ...
    'E_GPa', 32, 'I_m4', 0.0625, 'materialName', '', 'materialBasis', '', 'udlDown_kNpm', 10);
refModel = buildModelFromInputs(in);
rows(end+1) = flag('spans 12 m + 15 m: supports A, B, C at 0, 12, 27 m', ...
    isequal(c.SupportsTable.Data, {'A', 0, 'Pin'; 'B', 12, 'Roller'; 'C', 27, 'Roller'}));
rows(end+1) = flag('Apply model with 2 spans, RCC, 10 kN/m succeeds', ok && isempty(app.LastError));
rows(end+1) = flag('app model = buildModelFromInputs(the same inputs)', isequal(app.Model, refModel));
[~, refInfo] = buildModelFromTables(struct('spanLengths', [12 15], 'elementsPerSpan', [8 8], 'supportTypes', ...
    {{'Pin', 'Roller', 'Roller'}}, 'materialType', 'rcc', 'E', 32, 'I', 0.0625, 'udlDown', 10, 'materialName', '', ...
    'materialBasis', ''));
rows(end+1) = flag(['model summary = infoPanelHtml(''model'', summary of buildModelFromTables): headings, one bullet ' ...
    'per support, numbers highlighted, the modelling notes (not a load rating) in grey'], ...
    isequal(c.SummaryArea.HTMLSource, infoPanelHtml('model', refInfo.summary)) ...
    && ~isempty(strfind(c.SummaryArea.HTMLSource, '<h4>Supports</h4>')) ...
    && ~isempty(strfind(c.SummaryArea.HTMLSource, '<span class="num">12 m</span>')) ...
    && ~isempty(strfind(c.SummaryArea.HTMLSource, 'class="note"')) ...
    && ~isempty(strfind(htmlText(c.SummaryArea.HTMLSource), 'Linear, quasi-static analysis. Not a load rating or design check.')));
feval(c.EField.ValueChangedFcn, c.EField, struct('Value', 32, 'PreviousValue', 32));   % E typed: a preview, nothing applied
titleAfterE = axTitle(c.ModelAxes);
statusAfterE = c.StatusLabel.Text;
c.StatusLabel.Text = 'Another message.';  % e.g. a run finished meanwhile: a redraw must leave it
c.NumbersCheckBox.Value = true;
feval(c.NumbersCheckBox.ValueChangedFcn, c.NumbersCheckBox, struct('Value', true, 'PreviousValue', false));
titleWithNumbers = axTitle(c.ModelAxes);
statusWithNumbers = c.StatusLabel.Text;
c.NumbersCheckBox.Value = false;
feval(c.NumbersCheckBox.ValueChangedFcn, c.NumbersCheckBox, struct('Value', false, 'PreviousValue', true));
app.applyModelInputs();
rows(end+1) = flag(['editing E shows a preview and asks for Apply model; ticking node numbers keeps the preview and ' ...
    'the status line; Apply model shows the model again'], strncmp(titleAfterE, 'Preview', 7) ...
    && strncmp(statusAfterE, 'Model edited', 12) && strncmp(titleWithNumbers, 'Preview', 7) ...
    && strcmp(statusWithNumbers, 'Another message.') ...
    && strncmp(axTitle(c.ModelAxes), 'Bridge model', 12) && isequal(app.Model, refModel));
prep = prepareMovingLoad(refModel, defaultEnvelopeStations(refModel.nodes.x, 4));

% 3. A vehicle position equals the engine's result
app.setVehiclePosition(16.4);
ref = analyzeVehiclePosition(prep, refVehicle, 16.4, 1);
rows(end+1) = compareToReference('x_v = 16.4 m: max|U_app - U_engine| / max|U| [-]', ...
    max(abs(app.PositionResult.U - ref.U)) / max(abs(ref.U)), 0, [], 1e-12);
rows(end+1) = compareToReference('x_v = 16.4 m: max|R_app - R_engine| / max|R| [-]', ...
    max(abs(app.PositionResult.R - ref.R)) / max(abs(ref.R)), 0, [], 1e-12);
B = findNodeAtX(refModel, 12);
refRB = ref.R(2*B - 1);                   % R_B at x_v = 16.4 m [N], also checked in US units (section 12)
rows(end+1) = flag('reaction table shows 3 supports and R_B of the engine', size(c.ReactionsTable.Data, 1) == 3 ...
    && strcmp(c.ReactionsTable.Data{2, 4}, sprintf('%.3f', ref.R(2*B - 1) / 1e3)));
rows(end+1) = flag('beam, M, V and v axes are drawn', numel(c.BeamAxes.Children) > 20 && numel(c.MomentAxes.Children) >= 3 ...
    && numel(c.ShearAxes.Children) >= 3 && numel(c.DeflectionAxes.Children) >= 3);
rows(end+1) = flag('labels of the model, beam and M drawings are clipped to the axes (none left outside after a zoom)', ...
    textsClipped(c.ModelAxes) && textsClipped(c.BeamAxes) && textsClipped(c.MomentAxes));
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
envText = htmlText(c.EnvelopeInfo.HTMLSource);
rows(end+1) = flag(['x and x_v explained under the critical, reaction, sensitivity, readings and candidate tables and ' ...
    'in the slider readout; the run notes in a formatted box'], ...
    ~isempty(strfind(c.CriticalLegend.Text, 'x = location on the bridge')) ...
    && ~isempty(strfind(c.CriticalLegend.Text, 'x_v = position of the truck''s front axle')) ...
    && ~isempty(strfind(c.ReactionLegend.Text, 'x_v = front-axle position')) ...
    && ~isempty(strfind(c.SensitivityLegend.Text, 'weakened element')) ...
    && ~isempty(strfind(c.ReadingsLegend.Text, 'truck front-axle positions x_v')) ...
    && ~isempty(strfind(c.CandidateLegend.Text, 'candidate region on the bridge')) ...
    && ~isempty(strfind(c.PositionLabel.Text, '(front axle, measured from A)')) ...
    && ~isempty(strfind(c.EnvelopeInfo.HTMLSource, '<h4>Moving-load run</h4>')) ...
    && ~isempty(strfind(envText, sprintf('%d positions at step', app.MovingLoad.nCoarse))) ...
    && ~isempty(strfind(envText, 'Permanent model loads are included at every position.')));

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
feval(c.DirectionDropDown.ValueChangedFcn, c.DirectionDropDown, struct('Value', c.DirectionDropDown.Value, ...
    'PreviousValue', c.DirectionDropDown.Value));
statusDirection = c.StatusLabel.Text;
feval(c.StepField.ValueChangedFcn, c.StepField, struct('Value', 0.1, 'PreviousValue', 0.1));
statusStep = c.StatusLabel.Text;
rows(end+1) = flag(['direction or step edited: the status asks for Apply vehicle; the slider has round ticks ' ...
    '(-x crossing, from below 0)'], strncmp(statusDirection, 'Vehicle edited', 14) ...
    && strncmp(statusStep, 'Vehicle edited', 14) && roundSliderTicks(c.PositionSlider) && c.PositionSlider.Limits(1) < 0);
c.DirectionDropDown.Value = '+x (left to right)';
app.applyVehicleInputs();

% 7. Invalid input is reported and the previous model or vehicle is kept
before = app.Model;
c.SpansTable.Data{2, 1} = -15;
ok = app.applyModelInputs();
rows(end+1) = flag('span 2 length -15: rejected with a message naming ''Span 2'', model kept', ~ok ...
    && ~isempty(strfind(app.LastError, 'Span 2')) && isequal(app.Model, before));
c.SpansTable.Data{2, 1} = '15';            % text in a numeric cell: not a number, as for buildModelFromTables
app.onSpansEdited();
ok = app.applyModelInputs();
rows(end+1) = flag('span 2 typed as text ''15'': supports table shows no x for C and Apply names ''Span 2''', ~ok ...
    && isnan(c.SupportsTable.Data{3, 2}) && ~isempty(strfind(app.LastError, 'Span 2')) && isequal(app.Model, before));
c.SpansTable.Data{2, 1} = 15;
app.onSpansEdited();
c.SupportsTable.Data{3, 3} = 'Hinge';
ok = app.applyModelInputs();
rows(end+1) = flag('support C type ''Hinge'': rejected with a message naming ''Support C'', model kept', ~ok ...
    && ~isempty(strfind(app.LastError, 'Support C')) && isequal(app.Model, before));
c.SupportsTable.Data{3, 3} = 'Roller';
c.AxlesTable.Data{2, 1} = 'abc';
ok = app.applyVehicleInputs();
rows(end+1) = flag('axle 2 load ''abc'': rejected with a message naming ''Axle 2'', vehicle kept', ~ok ...
    && ~isempty(strfind(app.LastError, 'Axle 2')) && isequal(app.Vehicle, refVehicle));
c.AxlesTable.Data{2, 1} = 120;
app.applyVehicleInputs();

% 8. A unit slip is warned about
c.EField.Value = 32e9;                    % Pa typed into the GPa field
ok = app.applyModelInputs();
rows(end+1) = flag('E = 32e9 "GPa": model built and a unit warning reported in GPa (the unit typed)', ...
    ok && numel(app.ModelInfo.warnings) == 1 ...
    && ~isempty(strfind(app.ModelInfo.warnings{1}, 'RCC modulus E = 3.2e+10 GPa is outside the usual 10-70 GPa')));
c.EField.Value = 32;
app.applyModelInputs();

% 9. Damage tab (Stage 2) equals applyStiffnessDamage, compareHealthyDamaged and damageSensitivity
[nodeLabels, nodeX] = nodeChoices(refModel, SI);
rows(end+1) = flag('region drop-downs list every node (nodeChoices); support drop-down A, B, C with x', ...
    isequal(c.DamageFromDropDown.Items, nodeLabels) && isequal(c.HiddenToDropDown.Items, nodeLabels) ...
    && isequal(c.SupportDropDown.Items, {'A (x = 0 m)', 'B (x = 12 m)', 'C (x = 27 m)'}));
c.DamageFromDropDown.Value = nodeLabel(nodeLabels, nodeX, 9);      % nodes of the 12 m + 15 m model
c.DamageToDropDown.Value = nodeLabel(nodeLabels, nodeX, 13.875);   % (1.5 m and 1.875 m elements)
c.LossField.Value = 40;
ok = app.applyDamageInputs();
damagedElements = elementsBetween(refModel, 9, 13.875);
refDamaged = applyStiffnessDamage(refModel, damagedElements, 0.40);
rows(end+1) = flag('Apply damage 9-13.875 m, d = 40 %: app model = applyStiffnessDamage(...)', ok ...
    && isequal(app.DamagedModel, refDamaged) && isequal(app.Model, refModel));
rows(end+1) = flag('damage box names the elements and the chosen nodes (formatted, caveat in grey)', ...
    ~isempty(strfind(htmlText(c.DamageInfo.HTMLSource), sprintf('Elements %d-%d, %s to %s: EI_D = (1 - 0.4) EI = 0.6 EI', ...
    min(damagedElements), max(damagedElements), nodeLabel(nodeLabels, nodeX, 9), nodeLabel(nodeLabels, nodeX, 13.875)))) ...
    && ~isempty(strfind(c.DamageInfo.HTMLSource, '<h4>Applied damage</h4>')) ...
    && ~isempty(strfind(c.DamageInfo.HTMLSource, 'class="note"')));
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
rows(end+1) = flag('findings = infoPanelHtml(''findings'', damageComparisonSummary) (indeterminate, degree 1); sub-tab shown', ...
    isequal(c.DamageFindings.HTMLSource, infoPanelHtml('findings', damageComparisonSummary(refCmp, refModel))) ...
    && ~isempty(strfind(htmlText(c.DamageFindings.HTMLSource), 'degree 1')) ...
    && strcmp(c.DamageResultTabs.SelectedTab.Title, c.DamageCompareTab.Title));
th = appTheme();
curveColours = [th.healthyMax; th.healthyMin; th.damagedMax; th.damagedMin];
okColours = true;
for ax = {c.DamageMomentAxes, c.DamageShearAxes, c.DamageDeflectionAxes}
    [colours, styles] = curveStyles(ax{1});
    okColours = okColours && size(colours, 1) == 4 && isequal(sortrows(colours), sortrows(curveColours)) ...
        && all(strcmp(styles, '-'));
end
rows(end+1) = flag(['healthy vs damaged plots: 4 solid curves per plot in 4 colours (healthy blue / lighter blue, ' ...
    'damaged dark red / orange), no dash styles'], okColours && size(unique(curveColours, 'rows'), 1) == 4);
c.SensitivityDropDown.Value = c.SensitivityDropDown.Items{1};   % largest downward deflection
ok = app.runDamageSensitivity();
refSens = damageSensitivity(refModel, refVehicle, 0.40, 'vmin', 'Step', max(app.Step, 0.5), 'Direction', 1, ...
    'Refine', false);
rows(end+1) = flag('Sensitivity (vmin): app result = damageSensitivity(...)', ok ...
    && isequal(app.DamageSensitivity.change, refSens.change) && size(c.SensitivityTable.Data, 1) == numel(refSens.groups) ...
    && strcmp(c.DamageResultTabs.SelectedTab.Title, c.DamageSensitivityTab.Title));
items = c.SensitivityDropDown.Items;
codes = cellfun(@sensitivityQuantityCode, items, 'UniformOutput', false);
c.SensitivityDropDown.Value = items{strcmp(codes, 'Rmax')};
c.SupportDropDown.Value = 'B (x = 12 m)';
ok = app.runDamageSensitivity();
refSensR = damageSensitivity(refModel, refVehicle, 0.40, 'Rmax', 'Step', max(app.Step, 0.5), 'Direction', 1, ...
    'Refine', false, 'Node', B);
rows(end+1) = flag(['Sensitivity (Rmax at support B): app result = damageSensitivity(..., ''Node'', node of B); ' ...
    'the status names the rank-1 element'], ok && isequal(app.DamageSensitivity.change, refSensR.change) ...
    && ~isempty(strfind(c.StatusLabel.Text, sprintf('most influential: element(s) %s.', c.SensitivityTable.Data{1, 2}))));
lossKeep = c.LossField.Value;
c.LossField.Value = 1;                     % a small but real change: about 1e-4 of the axle loads
ok = app.runDamageSensitivity();
refSensR1 = damageSensitivity(refModel, refVehicle, 0.01, 'Rmax', 'Step', max(app.Step, 0.5), 'Direction', 1, ...
    'Refine', false, 'Node', B);
rows(end+1) = flag(['Sensitivity (Rmax at B), d = 1 %: changes of about 1e-4 of the axle loads are ranked (not called ' ...
    'a tie or round-off)'], ok && isequal(app.DamageSensitivity.change, refSensR1.change) ...
    && max(abs(refSensR1.change)) > 1e-5 * sum(refVehicle.axleLoads) ...
    && ~isempty(strfind(c.StatusLabel.Text, sprintf('most influential: element(s) %s.', c.SensitivityTable.Data{1, 2}))));
c.LossField.Value = lossKeep;
c.SensitivityDropDown.Value = items{1};
app.clearDamage();
rows(end+1) = flag('Clear damage: no damaged model, tables emptied, healthy model unchanged, no legend left', ...
    isempty(app.DamagedModel) && isempty(c.DamageTable.Data) && isequal(app.Model, refModel) ...
    && isempty(legendStrings(c.DamageMomentAxes)) && isempty(c.DamageMomentAxes.Children));
app.applyDamageInputs();                  % leave a valid damage for the callback sweep

% 10. Identification tab (Stage 3) equals syntheticObservations and identifySingleDamage
[sRef, pRef] = identificationDefaults(refModel, refVehicle, 1);
rows(end+1) = flag(['Stage 3 defaults in the tables: sensors S1-S3 at L/4, L/2, 3L/4; positions P1-P4 at L/4..L ' ...
    '(5L/4 has no axle on the 27 m beam); hidden loss limited to the 60 % search range'], ...
    isequal(pRef, [6.75 13.5 20.25 27]) && isequal(tableColumn(c.SensorsTable), sRef) ...
    && isequal(tableColumn(c.PositionsTable), pRef) && isequal(c.SensorsTable.RowName(:)', {'S1', 'S2', 'S3'}) ...
    && isequal(c.PositionsTable.RowName(:)', {'P1', 'P2', 'P3', 'P4'}) && c.HiddenLossField.Limits(2) == 60);
app.addIdentPoint('sensor');
sensorsAdded = tableColumn(c.SensorsTable);
rowNameAdded = c.SensorsTable.RowName{end};
app.addIdentPoint('truck position');
positionsAdded = tableColumn(c.PositionsTable);
app.removeIdentPoint('truck position');
for k = 1:4                               % 4 sensors: three removals leave one, the fourth is refused
    app.removeIdentPoint('sensor');
end
sensorsLeft = tableColumn(c.SensorsTable);
statusLast = c.StatusLabel.Text;
c.SensorsTable.Data = {6; 9};              % one spacing on would be 12 m = support B (zero readings)
app.addIdentPoint('sensor');
sensorsPastB = tableColumn(c.SensorsTable);
c.SensorsTable.Data = {20; 25};            % one spacing on would be 30 m, past the end of the 27 m beam
app.addIdentPoint('sensor');
sensorsPastEnd = tableColumn(c.SensorsTable);
c.SensorsTable.Data = num2cell(sRef(:));
c.SensorsTable.RowName = {'S1'; 'S2'; 'S3'};
rows(end+1) = flag(['+ Add never puts a point where it reads zero: sensor 23.625 m (27 m is support C), truck ' ...
    'position 29.8 m (32.6 m leaves no axle inside a span), 18 m instead of support B, 26 m instead of 30 m (off the ' ...
    'beam); - Remove keeps at least one'], ...
    isequal(sensorsAdded, [sRef, 23.625]) && strcmp(rowNameAdded, 'S4') && abs(positionsAdded(end) - 29.8) < 1e-9 ...
    && numel(positionsAdded) == 5 && isequal(sensorsPastB, [6 9 18]) && isequal(sensorsPastEnd, [20 25 26]) ...
    && isequal(sensorsLeft, sRef(1)) && strcmp(statusLast, 'At least one sensor is needed.'));
c.SensorsTable.Data = {6.75; NaN; 20.25};
okNaN = app.newEmptyReadings();
errNaN = app.LastError;
c.SensorsTable.Data = {6.75; 30; 20.25};
okOff = app.newEmptyReadings();
errOff = app.LastError;
c.SensorsTable.Data = num2cell(sRef(:));
c.PositionsTable.Data = {6.75; 13.5; NaN; 27};
okPos = app.newEmptyReadings();
errPos = app.LastError;
c.PositionsTable.Data = num2cell(pRef(:));
c.SensorsTable.Data = {6.75; 12; 20.25};     % sensor 2 on support B: always zero
app.generateSyntheticReadings();
okZeroRun = app.runIdentification();
errZero = app.LastError;
c.SensorsTable.Data = num2cell(sRef(:));
c.PositionsTable.Data = {0; 13.5; 27};       % x_v = 0: the front axle on support A, the others off the bridge
app.generateSyntheticReadings();
okZeroPos = app.runIdentification();
errZeroPos = app.LastError;
c.PositionsTable.Data = num2cell(pRef(:));
rows(end+1) = flag(['a sensor on a support, or a truck position with no axle inside a span, is named in the app''s words ' ...
    'when the search needs its noise (not ''NoiseAbsolute'')'], ...
    ~okZeroRun && strcmp(errZero, ['Sensor 2 (x = 12 m) reads zero for every truck position (it is on a support). ' ...
    'Remove it, or state Reading noise [mm] > 0.']) ...
    && ~okZeroPos && strcmp(errZeroPos, ['Truck position 1 (x_v = 0 m) gives zero readings at every sensor (no axle ' ...
    'inside a span). Remove it, or state Reading noise [mm] > 0.']));
rows(end+1) = flag('invalid table rows are named: ''Sensor 2: x must be a number'', ''Sensor 2: x = 30 m is not on the beam'', ''Truck position 3''', ...
    ~okNaN && strcmp(errNaN, 'Sensor 2: x must be a number (m).') ...
    && ~okOff && strcmp(errOff, 'Sensor 2: x = 30 m is not on the beam (0 to 27 m).') ...
    && ~okPos && strcmp(errPos, 'Truck position 3: x_v must be a number (m).'));
c.HiddenFromDropDown.Value = nodeLabel(nodeLabels, nodeX, 9);
c.HiddenToDropDown.Value = nodeLabel(nodeLabels, nodeX, 10.5);
c.DamageFromDropDown.Value = nodeLabel(nodeLabels, nodeX, 1.5);   % Stage 2 drop-downs differ from the hidden case
c.DamageToDropDown.Value = nodeLabel(nodeLabels, nodeX, 3);
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
[refSummary, refFlags] = identificationSummary(ref, truthRef);
pf = fitProfileData(ref, refModel);
base = double(pf.ratio);                  % as in plotFitProfile: ratio bars start at 1
cap = base + 4 * (pf.threshold - base);   % bars above this are cut and marked
nFit = numel(pf.value) + nnz(pf.value > cap) + (ref.best.group > 0) + 1 + (pf.healthyValue <= cap);   % bars, cut-off marks, best star, limit, no damage
rows(end+1) = flag(['candidate table and Summary = infoPanelHtml(''identSummary'', identificationSummary): sections, ' ...
    'fit check passed in green; fit sub-tab selected'], ...
    isequal(c.CandidateTable.Data, refData) && isequal(c.IdentResultText.HTMLSource, infoPanelHtml('identSummary', refSummary, refFlags)) ...
    && ~isempty(strfind(c.IdentResultText.HTMLSource, '<h4>Checks and flags</h4>')) ...
    && ~isempty(strfind(c.IdentResultText.HTMLSource, '<li class="ok">')) ...
    && strcmp(c.IdentResultTabs.SelectedTab.Title, 'Fit by location'));
rows(end+1) = flag('left box: best fit, every limiting flag in orange and a pointer to the Summary tab', ...
    isequal(c.IdentInfo.HTMLSource, infoPanelHtml('identBox', [refSummary(2); refFlags; {'Full result: "Summary" tab.'}], refFlags)) ...
    && numel(strfind(c.IdentInfo.HTMLSource, '<li class="warn">')) == numel(refFlags));
rows(end+1) = flag('RCC bridge: rccBaseline set and the spec section 7 caveat shown in the left box (orange)', ...
    app.IdentResult.rccBaseline && ~isempty(strfind(htmlText(c.IdentInfo.HTMLSource), 'RCC baseline:')) ...
    && ~isempty(strfind(c.IdentInfo.HTMLSource, 'class="warn"')));
rows(end+1) = flag('fit chart: one bar per candidate, cut-off markers, best-fit star, limit and no-damage lines', ...
    numel(c.FitAxes.Children) == nFit);
rows(end+1) = flag('fit chart legend names the region, the best fit and the limit', ...
    all(ismember({'in region', 'best fit', 'limit'}, legendStrings(c.FitAxes))));
rows(end+1) = flag('readings plot: 3 objects per sensor (healthy, best fit, readings)', ...
    numel(c.ReadingsAxes.Children) == 3 * numel(sRef));
rows(end+1) = flag('readings plot legend names each sensor by colour: S1 (x = 6.75 m), ...', ...
    isequal(legendStrings(c.ReadingsAxes), arrayfun(@(k) sprintf('S%d (x = %g m)', k, sRef(k)), 1:numel(sRef), ...
    'UniformOutput', false)));
ends = struct('x', [0 12 27], 'text', {{'A', 'B', 'C'}});
expected = bridgeDrawing(refModel, struct('SymbolSize', 0.04 * 27, 'Theme', appTheme(), 'Units', SI, ...
    'EndLabels', ends, 'Sensors', sRef, ...
    'Regions', ref.uncertaintyRegions, 'BestRegion', ref.best.x, 'BestLabel', ...
    sprintf('best fit: d = %s %%', formatNumber(100 * ref.best.d, 1)), 'TrueRegion', truthRef.x));
rows(end+1) = flag('drawing = bridgeDrawing with support letters, sensors, region, best fit and hidden case (count)', ...
    numel(c.IdentAxes.Children) == numel(expected));
c.SearchNoiseField.Value = 0;            % no noise stated: ratio method
ok = app.runIdentification();
pr = fitProfileData(app.IdentResult, refModel);
capR = 1 + 4 * (pr.threshold - 1);
rows(end+1) = flag('no noise stated: ratio method, its chart (bars from 1) and the "not a confidence region" flag', ok ...
    && strcmp(app.IdentResult.method, 'ratio') && numel(c.FitAxes.Children) == numel(pr.value) + nnz(pr.value > capR) ...
    + (app.IdentResult.best.group > 0) + 1 + (pr.healthyValue <= capR) ...
    && ~isempty(strfind(htmlText(c.IdentInfo.HTMLSource), 'No noise level stated: the listed candidates are NOT a confidence region.')));
c.SearchNoiseField.Value = 1;
c.RegionSizeDropDown.Value = '2 m regions';
ok = app.runIdentification();
rows(end+1) = flag('2 m candidate regions: groups = candidateGroups(model, 2)', ok ...
    && isequal(app.IdentResult.groups, candidateGroups(refModel, 2)));
c.RegionSizeDropDown.Value = 'Each element';
c.SensorsTable.Data = {5; 10};
ok = app.runIdentification();
rows(end+1) = flag('sensors changed after the readings: run refused with a message', ~ok ...
    && ~isempty(strfind(app.LastError, 'readings table')));
c.SensorsTable.Data = num2cell(sRef(:));
c.DirectionDropDown.Value = '-x (right to left)';
app.applyVehicleInputs();
[sNeg, pNeg] = identificationDefaults(refModel, refVehicle, -1);
app.addIdentPoint('truck position');
positionsNegAdded = tableColumn(c.PositionsTable);
app.removeIdentPoint('truck position');
positionsNegBack = tableColumn(c.PositionsTable);
c.PositionsTable.Data = {20; 15};          % -x: one spacing on is 10 m (25 m would be against the travel)
app.addIdentPoint('truck position');
positionsNegStep = tableColumn(c.PositionsTable);
c.PositionsTable.Data = num2cell(pNeg(:));
c.PositionsTable.RowName = arrayfun(@(k) sprintf('P%d', k), (1:numel(pNeg))', 'UniformOutput', false);
rows(end+1) = flag(['-x travel: + Add truck position continues in the travel direction (-2.8 m, inside the crossing ' ...
    'to -5.6 m; after 20, 15 m: 10 m)'], ...
    numel(positionsNegAdded) == numel(pNeg) + 1 && abs(positionsNegAdded(end) + 2.8) < 1e-9 ...
    && isequal(positionsNegBack, pNeg) && isequal(positionsNegStep, [20 15 10]));
okGen = app.generateSyntheticReadings();
uNeg = syntheticObservations(refModel, refVehicle, pNeg, sNeg, -1, 9, 10.5, 30, 1, 3);
okRun = app.runIdentification();
optsNeg = identificationOptions(refModel, 0, 1, 0, -1);
refNeg = identifySingleDamage(refModel, refVehicle, pNeg, sNeg, uNeg, optsNeg{:});
rows(end+1) = flag('-x travel: mirrored positions, readings and result = direct calls with direction -1', okGen && okRun ...
    && isequal(tableColumn(c.PositionsTable), pNeg) && isequal(c.ReadingsTable.Data, 1e3 * uNeg) ...
    && isequal([app.IdentResult.competing.group], [refNeg.competing.group]) && app.IdentResult.best.d == refNeg.best.d);
sensorsBeforeAdd = tableColumn(c.SensorsTable);
app.addIdentPoint('sensor');               % the result belongs to the old sensors: it is cleared
staleCleared = isempty(app.IdentResult) && isempty(c.CandidateTable.Data) ...
    && strncmp(c.StatusLabel.Text, 'Sensors or truck positions edited', 33);
app.removeIdentPoint('sensor');
rows(end+1) = flag('a sensor added after a run clears the old result (candidate table emptied) and says why', ...
    okRun && staleCleared && isequal(tableColumn(c.SensorsTable), sensorsBeforeAdd));
c.DirectionDropDown.Value = '+x (left to right)';
app.applyVehicleInputs();
app.generateSyntheticReadings();

% 11. Vehicle presets and the axle table
hl = presets(2);
app.choosePreset(hl.name);
statusPreset = c.StatusLabel.Text;
ok = app.applyVehicleInputs();
rows(end+1) = flag('preset chosen: the status asks for Apply vehicle; after it: "Vehicle applied: HL-93 ..., 3 axle(s), total 320.272 kN."', ...
    strncmp(statusPreset, 'Vehicle edited: press "Apply vehicle"', 37) ...
    && strcmp(c.StatusLabel.Text, sprintf('Vehicle applied: %s, 3 axle(s), total %g kN.', hl.name, sum(hl.loads))));
refHL = vehicleFromTable([8 32 32], [14 14], hl.name, US);           % AASHTO HL-93 axles typed in kip and ft
rows(end+1) = flag('preset HL-93: 3 axles in the table, its name, and the note (axle loads only, no lane load)', ok ...
    && size(c.AxlesTable.Data, 1) == 3 && strcmp(c.VehicleNameField.Value, hl.name) ...
    && ~isempty(strfind(c.PresetNote.Text, 'no design lane load')));
rows(end+1) = compareToReference('preset HL-93 applied in SI: max relative difference to 8, 32, 32 kip and 14, 14 ft [-]', ...
    max([abs(app.Vehicle.axleLoads(:) - refHL.axleLoads(:)) ./ refHL.axleLoads(:); ...
    abs(app.Vehicle.axleSpacings(:) - refHL.axleSpacings(:)) ./ refHL.axleSpacings(:)]), 0, [], 1e-12);
rows(end+1) = flag('axle total line = sum of the HL-93 loads and spacings in kN and m', strncmp(c.AxleTotalLabel.Text, ...
    sprintf('Total %g kN, length %g m;', sum(hl.loads), sum(hl.spacings)), 30));
app.addAxle();
nAdded = size(c.AxlesTable.Data, 1);
lastSpacing = c.AxlesTable.Data{3, 2};
app.removeAxle();
rows(end+1) = flag('+ Add axle: 4 axles, the new one 1.2 m behind; - Remove last axle: 3; editing sets the preset to Custom', ...
    nAdded == 4 && abs(lastSpacing - 1.2) < 1e-12 && size(c.AxlesTable.Data, 1) == 3 ...
    && strcmp(c.PresetDropDown.Value, 'Custom') && strncmp(c.StatusLabel.Text, 'Vehicle edited', 14));
app.choosePreset(truckName);
ok = app.applyVehicleInputs();
rows(end+1) = flag('back to the first preset: vehicle = vehicleFromInputs(''80 120 120'', ''4.2 1.4'') again', ok ...
    && isequal(app.Vehicle, refVehicle));

% 12. US customary units: every input converted, the same SI model, results and labels in US units
kip = US.force.toSI;
ft = US.length.toSI;
inch = US.deflection.toSI;
sensorsSI = c.SensorsTable.Data;
c.SpansTable.Data{1, 1} = 0;               % an invalid input (shown as a preview only)
app.onSpansEdited();
app.setUnitSystem('US');
rows(end+1) = flag('switch to US with span 1 = 0: refused (units, labels and inputs stay SI), the error names ''Span 1''', ...
    strcmp(app.Units.name, 'SI') && strcmp(c.UnitsDropDown.Value, SI.label) && ~isempty(strfind(app.LastError, 'Span 1')) ...
    && ~isempty(strfind(app.LastError, 'units stay SI')) && strcmp(c.SensorsTable.ColumnName{1}, 'x [m]') ...
    && isequal(c.SensorsTable.Data, sensorsSI) && isequal(c.SpansTable.Data, {0, 8; 15, 8}) && isequal(app.Model, refModel));
c.SpansTable.Data{1, 1} = 12;
app.onSpansEdited();
c.SearchNoiseAbsField.Value = 0.05;        % mm; converted to in by the switch
c.SensitivityStepField.Value = 0.5;
app.setUnitSystem('US');
spansUS = [c.SpansTable.Data{:, 1}];
loadsUS = [c.AxlesTable.Data{:, 1}];
rows(end+1) = compareToReference(['US: max relative error of the converted inputs (spans, E, I, load, axles, ' ...
    'position and sweep steps, reading noise) [-]'], ...
    max(abs([spansUS * ft, c.EField.Value * US.modulus.toSI, c.IField.Value * US.inertia.toSI, ...
    c.UDLField.Value * US.distributed.toSI, loadsUS * kip, c.StepField.Value * ft, c.SensitivityStepField.Value * ft, ...
    c.SearchNoiseAbsField.Value * inch] ./ [12 15 32e9 0.0625 10e3 80e3 120e3 120e3 0.1 0.5 0.05e-3] - 1)), 0, [], 1e-11);
rows(end+1) = flag('US: supports table x = 0, 12, 27 m in ft', ...
    max(abs([c.SupportsTable.Data{:, 2}] - [0 12 27] / ft)) < 1e-9);
[sDef, pDef] = identificationDefaults(refModel, refVehicle, 1);
rows(end+1) = flag('US: default sensors and truck positions written in ft (L/4, L/2, 3L/4 of the 27 m beam)', ...
    max(abs(tableColumn(c.SensorsTable) * ft ./ sDef - 1)) < 1e-11 ...
    && max(abs(tableColumn(c.PositionsTable) * ft ./ pDef - 1)) < 1e-11 && strcmp(c.PositionsTable.ColumnName{1}, 'x_v [ft]'));
rows(end+1) = flag(['US: emptied result tables keep no header in SI units; readings tab ''Readings [in]''; ' ...
    'noise tooltip in in; numeric fields shown with 6 digits'], noSIHeaders(c.CriticalTable) ...
    && noSIHeaders(c.EnvReactionsTable) && noSIHeaders(c.SensitivityTable) && noSIHeaders(c.CandidateTable) ...
    && strcmp(c.IdentReadingsTab.Title, 'Readings [in]') && ~isempty(strfind(c.SearchNoiseField.Tooltip, '0 in')) ...
    && strcmp(c.EField.ValueDisplayFormat, '%.6g') && strcmp(c.IField.ValueDisplayFormat, '%.6g'));
stApp = solveStaticModel(app.Model);
stRef = solveStaticModel(refModel);
rows(end+1) = compareToReference('US: model = SI model: max|U_app - U_SI| / max|U| under the permanent load [-]', ...
    max(abs(stApp.U - stRef.U)) / max(abs(stRef.U)), 0, [], 1e-9);
rows(end+1) = flag('US: same nodes (within 1e-9 m), supports and elements as the SI model', ...
    max(abs(app.Model.nodes.x - refModel.nodes.x)) < 1e-9 && isequal(app.Model.supports, refModel.supports) ...
    && isequal(app.Model.elements.conn, refModel.elements.conn));
rows(end+1) = compareToReference('US: vehicle = SI vehicle: max relative difference of axle loads and spacings [-]', ...
    max([abs(app.Vehicle.axleLoads(:) ./ refVehicle.axleLoads(:) - 1); ...
    abs(app.Vehicle.axleSpacings(:) ./ refVehicle.axleSpacings(:) - 1)]), ...
    0, [], 1e-11);
[nodeLabelsUS, nodeXUS] = nodeChoices(app.Model, US);
rows(end+1) = flag('US: headers, labels and drop-downs in ft, kip, ksi, in^4, kip/ft and in', ...
    strcmp(c.SpansTable.ColumnName{1}, 'Length [ft]') && strcmp(c.SupportsTable.ColumnName{2}, 'x [ft]') ...
    && strcmp(c.ELabel.Text, 'E [ksi]') && ~isempty(strfind(c.ILabel.Text, '[in^4]')) ...
    && strcmp(c.UDLLabel.Text, 'Uniform load, down [kip/ft]') && strcmp(c.AxlesTable.ColumnName{1}, 'Load [kip]') ...
    && strcmp(c.StepLabel.Text, 'Position step [ft]') && strcmp(c.SearchNoiseAbsLabel.Text, 'Reading noise [in]') ...
    && isequal(c.RegionSizeDropDown.Items, {'Each element', '6 ft regions', '12 ft regions'}) ...
    && isequal(c.DamageFromDropDown.Items, nodeLabelsUS) ...
    && strcmp(c.SupportDropDown.Items{2}, sprintf('B (x = %g ft)', 12 / ft)));
app.setVehiclePosition(16.4);
rows(end+1) = compareToReference('US: R_B at x_v = 16.4 m in the reaction table [kip] (shown to 3 decimals)', ...
    str2double(c.ReactionsTable.Data{2, 4}), refRB / kip, 6e-4);
rows(end+1) = flag('US: reaction table header and position text in kip and ft', ...
    strcmp(c.ReactionsTable.ColumnName{4}, 'Force [kip]') && strcmp(c.ReactionsTable.ColumnName{5}, 'Couple [kip*ft]') ...
    && strcmp(c.ReactionsLabel.Text, 'Support reactions (forces + up, couples + CCW)') ...
    && ~isempty(strfind(c.PositionLabel.Text, sprintf('x_v = %.3f ft (front axle, measured from A)', 16.4 / ft))));
rows(end+1) = flag('US: M, V and v diagrams drawn over x = 0 to 27 m in ft', ...
    max(abs([c.MomentAxes.XLim, c.ShearAxes.XLim, c.DeflectionAxes.XLim] - repmat([0 27] / ft, 1, 3))) < 1e-9);
slider = c.PositionSlider;
xvUS = generateVehiclePositions(app.Model, app.Vehicle, app.Step, 1);   % the crossing [m]
slider.Value = 10 / ft;
feval(slider.ValueChangedFcn, slider, struct('Value', slider.Value, 'PreviousValue', 0));
xReleased = app.Position;
feval(slider.ValueChangingFcn, slider, struct('Value', 5 / ft));
rows(end+1) = flag('US: slider ticks are round (1, 2 or 5 x 10^k ft) and the non-round crossing end has no label', ...
    roundSliderTicks(slider));
rows(end+1) = flag('US: slider moved to 32.8 ft and dragged through 16.4 ft puts the front axle at 10 m and 5 m', ...
    abs(xReleased - 10) < 1e-9 && abs(app.Position - 5) < 1e-9 && max(abs(slider.Limits - [min(xvUS), max(xvUS)] / ft)) < 1e-9);
app.setVehiclePosition(16.4);
ok = app.runEnvelopes();
rows(end+1) = compareToReference('US: critical values = runMovingLoad of the SI model: max relative difference [-]', ...
    max(abs([app.MovingLoad.critical.value] - [refML.critical.value]) ./ abs([refML.critical.value])), 0, [], 1e-9);
rows(end+1) = flag('US: critical table = criticalTableData(result, US) (kip*ft, kip, in, ft)', ok ...
    && isequal(c.CriticalTable.Data, criticalTableData(app.MovingLoad, US)) ...
    && strcmp(c.CriticalTable.ColumnName{4}, 'x [ft]'));
[envData, envColumns] = reactionEnvelopeTableData(app.MovingLoad, app.Model.nodes.x, US);
rows(end+1) = flag('US: reaction envelope table = reactionEnvelopeTableData(result, x, US); envelopes drawn in ft', ...
    isequal(c.EnvReactionsTable.Data, envData) && isequal(c.EnvReactionsTable.ColumnName(:), envColumns(:)) ...
    && max(abs(c.EnvMomentAxes.XLim - [0 27] / ft)) < 1e-9);
c.HiddenFromDropDown.Value = nodeLabel(nodeLabelsUS, nodeXUS, 9);
c.HiddenToDropDown.Value = nodeLabel(nodeLabelsUS, nodeXUS, 10.5);
c.DamageFromDropDown.Value = nodeLabel(nodeLabelsUS, nodeXUS, 1.5);
c.HiddenLossField.Value = 30;
c.SyntheticNoiseField.Value = 1;
c.SeedField.Value = 3;
okGen = app.generateSyntheticReadings();
sUS = tableColumn(c.SensorsTable) * ft;                                   % the table values, in ft
pUS = tableColumn(c.PositionsTable) * ft;
uUS = syntheticObservations(app.Model, app.Vehicle, pUS, sUS, 1, nodeXUS(abs(nodeXUS - 9) < 1e-6), ...
    nodeXUS(abs(nodeXUS - 10.5) < 1e-6), 30, 1, 3);
rows(end+1) = compareToReference('US: readings table [in] = syntheticObservations(...) / 0.0254: max relative difference [-]', ...
    max(max(abs(c.ReadingsTable.Data * US.deflection.toSI - uUS))) / max(abs(uUS(:))), 0, [], 1e-12);
c.SearchNoiseField.Value = 1;
c.RegionSizeDropDown.Value = '6 ft regions';
okRun = app.runIdentification();
noiseUS = c.SearchNoiseAbsField.Value;    % 0.05 mm converted to in
optsUS = identificationOptions(app.Model, candidateRegionLength('6 ft regions', US), 1, noiseUS, 1, US);
refUS = identifySingleDamage(app.Model, app.Vehicle, pUS, sUS, readingsFromTable(c.ReadingsTable.Data, numel(sUS), ...
    numel(pUS), US), optsUS{:});
rows(end+1) = flag(['US: identification (6 ft regions, noise 1 % + 0.05 mm in in) = identifySingleDamage(...); ' ...
    'table and summary in ft and in'], okGen && okRun && abs(noiseUS * inch - 0.05e-3) < 1e-15 && isequal([app.IdentResult.competing.group], [refUS.competing.group]) ...
    && app.IdentResult.best.d == refUS.best.d && isequal(c.CandidateTable.Data, identificationTableData(refUS, US)) ...
    && isequal(c.IdentResultText.HTMLSource, summaryHtml(refUS, app.IdentTruth, US)) ...
    && strcmp(c.ReadingsTable.RowName{1}, sprintf('S1 (x = %g ft)', sUS(1) / ft)));
app.setUnitSystem('SI');
rows(end+1) = flag('back to SI: unedited inputs restored exactly; model and vehicle isequal to the SI ones', ...
    isequal(c.SpansTable.Data, {12, 8; 15, 8}) && c.EField.Value == 32 && c.StepField.Value == 0.1 ...
    && c.SensitivityStepField.Value == 0.5 && c.SearchNoiseAbsField.Value == 0.05 ...
    && isequal(app.Model, refModel) && isequal(app.Vehicle, refVehicle) && strcmp(c.ELabel.Text, 'E [GPa]') ...
    && strcmp(c.IdentReadingsTab.Title, 'Readings [mm]'));
c.EField.Value = 200;                     % RCC with the steel default E typed: a switch must not change it
unusual = warning('off', 'BridgeFE:unusualModulus');
app.setUnitSystem('US');
eUS = c.EField.Value;
EIUS = app.Model.elements.EI(1);
app.setUnitSystem('SI');
warning(unusual);
rows(end+1) = flag('RCC with E = 200 GPa typed: the switch keeps E (200 GPa in ksi, model EI = 200 GPa x Ieff) and back', ...
    abs(eUS * US.modulus.toSI / 200e9 - 1) < 1e-11 && abs(EIUS / (200e9 * 0.0625) - 1) < 1e-11 ...
    && c.EField.Value == 200 && strcmp(c.MaterialDropDown.Value, 'RCC'));
c.EField.Value = 32;
app.applyModelInputs();
c.SensorsTable.Data = {4; 8; 12; 16};     % the user's own sensors: a pure unit switch keeps them (converted)
app.setUnitSystem('US');
sensorsUS = tableColumn(c.SensorsTable);
app.setUnitSystem('SI');                  % no pending edits: an exact round trip
rows(end+1) = flag('your sensors survive a pure unit switch: 4, 8, 12, 16 m shown in ft, and exactly 4, 8, 12, 16 m again in SI', ...
    numel(sensorsUS) == 4 && max(abs(sensorsUS * ft ./ [4 8 12 16] - 1)) < 1e-11 ...
    && isequal(c.SensorsTable.Data, {4; 8; 12; 16}) ...
    && isequal(c.SensorsTable.RowName(:)', {'S1', 'S2', 'S3', 'S4'}) ...
    && ~isempty(strfind(c.StatusLabel.Text, 'Every input was converted; press the run buttons')));
app.setUnitSystem('US');
app.addAxle();                            % an axle added in US units
nUS = size(c.AxlesTable.Data, 1);
addedUS = c.AxlesTable.Data{3, 2};
okAdd = app.applyVehicleInputs();
rows(end+1) = flag('US: + Add axle puts the new axle 1.2 m (3.937 ft) behind the last one', okAdd && nUS == 4 ...
    && abs(addedUS - 1.2 / ft) < 1e-9 && abs(app.Vehicle.axleSpacings(3) - 1.2) < 1e-12);
c.DamageFromDropDown.Value = nodeLabel(nodeLabelsUS, nodeXUS, 9);
c.DamageToDropDown.Value = nodeLabel(nodeLabelsUS, nodeXUS, 3);
okOrder = app.applyDamageInputs();
rows(end+1) = flag('US: a damaged region ''to'' left of ''from'' is refused with the node labels in ft', ~okOrder ...
    && ~isempty(strfind(app.LastError, 'Damaged region: choose a "to" node to the right of the "from" node')) ...
    && ~isempty(strfind(app.LastError, sprintf('(x = %g ft)', 9 / ft))));
c.SpansTable.Data{2, 1} = 50;             % edited in ft: converted on the switch back, not restored
app.setUnitSystem('SI');
rows(end+1) = flag('span 2 edited to 50 ft: 15.24 m after the switch back; the unedited span 1 is 12 m again', ...
    c.SpansTable.Data{2, 1} == 15.24 && c.SpansTable.Data{1, 1} == 12 && abs(app.Model.nodes.x(end) - 27.24) < 1e-12);
sDefaults = identificationDefaults(app.Model, app.Vehicle, 1);     % the new 27.24 m beam, 4 axles
rows(end+1) = flag(['a switch that applies a pending span edit (50 ft) gives the default sensors for the new beam ' ...
    '(the kept 4, 8, 12, 16 m would belong to the old one) and says so'], ...
    numel(tableColumn(c.SensorsTable)) == numel(sDefaults) && max(abs(tableColumn(c.SensorsTable) - sDefaults)) < 1e-9 ...
    && ~isempty(strfind(c.StatusLabel.Text, 'so the sensors and truck positions are the defaults')));
loadsBack = [c.AxlesTable.Data{:, 1}];
gapsBack = [c.AxlesTable.Data{1:end-1, 2}];
rows(end+1) = flag('axle added in US: back in SI the first 3 axles are exactly 80, 120, 120 kN at 4.2, 1.4 m again', ...
    isequal(loadsBack(1:3), [80 120 120]) && isequal(gapsBack(1:2), [4.2 1.4]) && abs(loadsBack(4) - 120) < 1e-9 ...
    && abs(gapsBack(3) - 1.2) < 1e-9);
c.SpansTable.Data{2, 1} = 15;
app.applyModelInputs();

% 12b. Apply model, a preset and a sensor at the beam end in US units
app.setUnitSystem('US');
okApply = app.applyModelInputs();          % pressed in US units: the defaults are written in ft
[sNow, pNow] = identificationDefaults(app.Model, app.Vehicle, 1);   % the vehicle now has 4 axles
rows(end+1) = flag('US: Apply model writes the default sensors and truck positions in ft', okApply ...
    && max(abs(tableColumn(c.SensorsTable) * ft ./ sNow - 1)) < 1e-11 ...
    && max(abs(tableColumn(c.PositionsTable) * ft ./ pNow - 1)) < 1e-11);
eKeep = c.EField.Value;
c.EField.Value = 200;                      % RCC, 200 ksi typed (1.38 GPa): the message speaks in ksi
okSlip = app.applyModelInputs();
slipUS = app.ModelInfo.warnings;
c.EField.Value = eKeep;
okKeep = app.applyModelInputs();
rows(end+1) = flag('US unit slip: "RCC modulus E = 200 ksi is outside the usual 1450.38-10152.6 ksi" (10-70 GPa in ksi)', ...
    okSlip && okKeep && strcmp(c.MaterialDropDown.Value, 'RCC') && numel(slipUS) == 1 ...
    && ~isempty(strfind(slipUS{1}, 'RCC modulus E = 200 ksi is outside the usual 1450.38-10152.6 ksi')) ...
    && isempty(app.ModelInfo.warnings));
app.choosePreset(hl.name);
okHL = app.applyVehicleInputs();
rows(end+1) = flag('US: preset HL-93 fills 8, 32, 32 kip at 14, 14 ft; applied = vehicleFromTable(..., US)', okHL ...
    && isequal([c.AxlesTable.Data{:, 1}], [8 32 32]) && isequal([c.AxlesTable.Data{1:2, 2}], [14 14]) ...
    && max(abs([app.Vehicle.axleLoads(:) ./ refHL.axleLoads(:); app.Vehicle.axleSpacings(:) ./ refHL.axleSpacings(:)] - 1)) < 1e-12);
c.SensorsTable.Data = {str2double(sprintf('%g', 13.5 / ft)); str2double(sprintf('%g', 27 / ft))};   % as shown (6 digits)
okEnd = app.newEmptyReadings();
rows(end+1) = flag('US: a sensor typed at the beam end as shown (88.5827 ft) is accepted (readings row S2 at the end)', ...
    okEnd && strcmp(c.ReadingsTable.RowName{2}, sprintf('S2 (x = %g ft)', 27 / ft)));
c.DirectionDropDown.Value = '-x (right to left)';   % a pending edit: the switch applies it
app.setUnitSystem('SI');
[~, pPending] = identificationDefaults(app.Model, app.Vehicle, -1);
rows(end+1) = flag(['a switch that applies a pending direction edit gives the default truck positions for -x (the ' ...
    'kept ones would not fit) and says so'], app.Direction == -1 && max(abs(tableColumn(c.PositionsTable) - pPending)) < 1e-9 ...
    && ~isempty(strfind(c.StatusLabel.Text, 'so the sensors and truck positions are the defaults')));
c.DirectionDropDown.Value = '+x (left to right)';
app.choosePreset(truckName);
app.applyVehicleInputs();

% 12c. A free end: the Rmax support drop-down lists only the supported ends, each at its own node
c.SupportsTable.Data{1, 3} = 'Free';      % 12 m overhang at A, supports at B (pin) and C (roller)
c.SupportsTable.Data{2, 3} = 'Pin';
okFree = app.applyModelInputs();
freeModel = app.Model;
c.SensitivityDropDown.Value = items{strcmp(codes, 'Rmax')};
c.SupportDropDown.Value = 'C (x = 27 m)';
okSens = app.runDamageSensitivity();
refSensC = damageSensitivity(freeModel, refVehicle, c.LossField.Value / 100, 'Rmax', 'Step', max(app.Step, 0.5), ...
    'Direction', 1, 'Refine', false, 'Node', findNodeAtX(freeModel, 27));
rows(end+1) = flag(['A Free: support drop-down B, C only; Rmax at C = damageSensitivity(..., ''Node'', node at 27 m); ' ...
    'the beam is determinate, so the status names no "most influential" element'], ...
    okFree && okSens && isequal(c.SupportDropDown.Items, {'B (x = 12 m)', 'C (x = 27 m)'}) ...
    && isequal(app.DamageSensitivity.change, refSensC.change) ...
    && max(abs(refSensC.change)) <= 1e-9 * abs(refSensC.healthy) ...    % round-off only
    && ~isempty(strfind(c.StatusLabel.Text, 'the response is the same for every location')));
c.SensitivityDropDown.Value = items{1};
c.SupportsTable.Data{1, 3} = 'Pin';
c.SupportsTable.Data{2, 3} = 'Roller';
okSweep = app.applyModelInputs() && isequal(app.Model, refModel);
okSweep = app.applyDamageInputs() && okSweep;    % a valid damage and readings again for the callback sweep
okSweep = app.generateSyntheticReadings() && okSweep;

% 13. Every button, value and cell-edit callback runs without error
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
    if isprop(h, 'CellEditCallback') && ~isempty(h.CellEditCallback)
        calls{end+1} = {h.CellEditCallback, struct('Indices', [1 1], 'PreviousData', [], 'NewData', [], ...
            'EditData', '', 'Error', '')}; %#ok<AGROW>
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
    if isprop(h, 'Text') && strcmp(h.Text, 'Run identification')
        % MATLAB lists children newest first, so the sweep may reach this button before
        % "Generate synthetic readings": give it the readings it needs, whatever the order.
        if ~app.generateSyntheticReadings()
            failures{end+1} = sprintf('Generate synthetic readings: %s', app.LastError); %#ok<AGROW>
        end
    end
    for j = 1:numel(calls)
        nCalls = nCalls + 1;
        seen = app.LastError;
        try
            feval(calls{j}{1}, h, calls{j}{2});
        catch err
            failures{end+1} = err.message; %#ok<AGROW>
        end
        if ~isempty(app.LastError) && ~strcmp(app.LastError, seen)   % reported by the app (alert), not thrown
            failures{end+1} = sprintf('reported by the app: %s', app.LastError); %#ok<AGROW>
        end
    end
end
if ~isempty(failures)
    fprintf('  callback errors:\n');
    fprintf('    %s\n', failures{:});
end
rows(end+1) = flag(sprintf(['%d callbacks invoked (buttons, fields, tables, slider, tabs) without an error ' ...
    'thrown or reported, after a valid set-up'], nCalls), okSweep && isempty(failures) && nCalls >= 20);

% 14. Verification tab (optional, runs the whole suite)
if includeVerification
    out = app.runVerification();
    rows(end+1) = flag('Verification tab: test suite reports 0 failed', ~isempty(regexp(out, 'Total: \d+ passed, 0 failed', 'once')));
end

reportComparisons('BridgeConditionApp driven through its inputs vs direct engine calls', rows);
if nargout == 0
    clear rows   % no 'ans = 1xN struct array' echo when called as a command
end
end

function s = legendStrings(ax)
% Legend labels of an axes: MATLAB's ax.Legend is [] or a Legend object with the labels in .String
% (the Octave stand-ins store the same shape).
lg = ax.Legend;
if isempty(lg)
    s = {};
else
    s = lg.String;
end
end

function ok = textsClipped(ax)
% True when AX has text and every text object on it is clipped to the axes (MATLAB Text objects, whose
% Clipping may read back as an on/off enumeration, or the Octave stand-ins, which record the call).
ok = true;
n = 0;
kids = ax.Children;
for k = 1:numel(kids)
    if iscell(kids)
        h = kids{k};
    else
        h = kids(k);
    end
    if isa(h, 'MockGraphic')
        if strcmp(h.Type, 'text')
            n = n + 1;
            i = find(cellfun(@(v) ischar(v) && strcmp(v, 'Clipping'), h.Args), 1);
            ok = ok && ~isempty(i) && strcmp(h.Args{i + 1}, 'on');
        end
    elseif isprop(h, 'Type') && strcmp(h.Type, 'text')
        n = n + 1;
        ok = ok && strcmp(char(h.Clipping), 'on');
    end
end
ok = ok && n > 0;
end

function ok = roundSliderTicks(slider)
% Ticks of 1, 2 or 5 x 10^k inside the limits (4 to 11 of them, none -0), the last one less than a step from
% the upper limit: a non-round limit gets no label of its own (MATLAB's automatic ticks label it).
t = slider.MajorTicks;
lim = slider.Limits;
ok = numel(t) >= 4 && numel(t) <= 11 && ~any(t == 0 & 1 ./ t < 0);
if ok
    step = t(2) - t(1);
    m = step / 10 ^ floor(log10(step) + 1e-12);
    ok = any(abs(m - [1 2 5]) < 1e-9) && all(abs(diff(t) - step) < 1e-9 * step) ...
        && all(abs(t / step - round(t / step)) < 1e-6) && t(1) >= lim(1) - 1e-9 && t(end) <= lim(2) + 1e-9 ...
        && lim(2) - t(end) < step && t(1) - lim(1) < step;
end
end

function t = htmlText(html)
% Text of an information box (uihtml): the style sheet and tags removed, &, < and > restored.
t = regexprep(html, '<style>.*</style>', '');
t = regexprep(t, '<[^>]*>', '');
t = strrep(strrep(strrep(t, '&lt;', '<'), '&gt;', '>'), '&amp;', '&');
end

function h = summaryHtml(result, truth, U)
% The Summary sub-tab expected for an identification result (identificationSummary, formatted).
[lines, flags] = identificationSummary(result, truth, U);
h = infoPanelHtml('identSummary', lines, flags);
end

function t = axTitle(ax)
% Title text of an axes (MATLAB Text object, or the stand-ins' plain text).
t = ax.Title;
if isobject(t)
    t = t.String;
end
if iscell(t)
    t = strjoin(t, ' ');
end
end

function v = tableColumn(tbl)
% The numbers of a one-column table, as a row.
d = tbl.Data;
if iscell(d)
    v = cellfun(@double, d(:)');
else
    v = double(d(:)');
end
end

function [colours, styles] = curveStyles(ax)
% Colour and line style of every curve with more than 2 points (MATLAB Line objects or the stand-ins).
colours = zeros(0, 3);
styles = {};
kids = ax.Children;
for k = 1:numel(kids)
    if iscell(kids)
        h = kids{k};
    else
        h = kids(k);
    end
    if isa(h, 'MockGraphic')
        if ~strcmp(h.Type, 'plot') || numel(h.Args{1}) <= 2
            continue
        end
        a = h.Args;
        i = find(cellfun(@(v) ischar(v) && strcmp(v, 'Color'), a), 1);
        colours(end+1, :) = a{i + 1}; %#ok<AGROW>
        j = find(cellfun(@(v) ischar(v) && strcmp(v, 'LineStyle'), a), 1);
        if isempty(j)
            styles{end+1} = '-'; %#ok<AGROW>
        else
            styles{end+1} = a{j + 1}; %#ok<AGROW>
        end
    elseif isprop(h, 'XData') && isprop(h, 'LineStyle') && numel(h.XData) > 2
        colours(end+1, :) = h.Color; %#ok<AGROW>
        styles{end+1} = char(h.LineStyle); %#ok<AGROW>
    end
end
end

function ok = noSIHeaders(tbl)
% True when no column header of TBL names an SI unit (m, mm, kN, kN*m).
names = tbl.ColumnName;
if ischar(names)
    names = {names};
end
ok = all(cellfun(@isempty, regexp(names, '\[(m|mm|kN|kN\*m)\]', 'once')));
end

function label = nodeLabel(labels, x, value)
% Drop-down item of the node at x = VALUE [m] (labels and x from nodeChoices).
label = labels{abs(x - value) < 1e-6};
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

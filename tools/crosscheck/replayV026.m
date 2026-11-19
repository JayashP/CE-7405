function replayV026()
%REPLAYV026 Replay of the user's MATLAB run in V-026 part 2a (spans 20 + 10 m, HL-93, US units).
%   Octave: addpath('tools/gui_mock'); addProjectPaths; addpath('tools/crosscheck'); replayV026
%   Prints what the screenshots show, for a digit-by-digit comparison (VERIFICATION_LOG V-026).
app = BridgeConditionApp(); c = app.Controls;
c.SpansTable.Data = {20, 16; 10, 10}; app.onSpansEdited();
presets = vehiclePresets(unitSystem('SI'));
app.choosePreset(presets(2).name);
fprintf('SI table after HL-93: loads %s kN, spacings %s m\n', mat2str([c.AxlesTable.Data{:,1}], 8), mat2str([c.AxlesTable.Data{1:2,2}], 8));
app.setUnitSystem('US');
fprintf('US table: loads %s kip, spacings %s ft; step %s ft; E %.10g ksi, I %.10g in^4\n', mat2str([c.AxlesTable.Data{:,1}], 12), ...
    mat2str([c.AxlesTable.Data{1:2,2}], 12), num2str(c.StepField.Value, 12), c.EField.Value, c.IField.Value);
fprintf('summary EI line: %s\n', c.SummaryArea.Value{4});
fprintf('reactions: %s\n', strjoin(c.ReactionsTable.Data(:, 4)', ' | '));
fprintf('sensors "%s"; positions "%s"; hidden %s to %s\n', c.SensorField.Value, c.IdentPositionsField.Value, ...
    c.HiddenFromDropDown.Value, c.HiddenToDropDown.Value);
ok1 = app.generateSyntheticReadings();
ok2 = app.runIdentification();
fprintf('ok %d %d; status: %s\n', ok1, ok2, c.StatusLabel.Text);
d = c.CandidateTable.Data;
for r = 1:size(d, 1)
    fprintf('  %s\n', strjoin(cellfun(@(v) num2str(v), d(r, :), 'UniformOutput', false), ' | '));
end
fprintf('%s\n', c.IdentInfo.Value{:});
fprintf('readings tab: %s\n', c.IdentReadingsTab.Title);
delete(app);
end

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
summary = plainLines(c.SummaryArea.HTMLSource);        % M10: the box is formatted HTML
fprintf('summary EI line: %s\n', summary{find(~cellfun(@isempty, strfind(summary, 'EI = ')), 1)});
fprintf('reactions: %s\n', strjoin(c.ReactionsTable.Data(:, 4)', ' | '));
fprintf('sensors %s; positions %s; hidden %s to %s\n', mat2str([c.SensorsTable.Data{:}], 6), ...
    mat2str([c.PositionsTable.Data{:}], 6), ...
    c.HiddenFromDropDown.Value, c.HiddenToDropDown.Value);
ok1 = app.generateSyntheticReadings();
ok2 = app.runIdentification();
fprintf('ok %d %d; status: %s\n', ok1, ok2, c.StatusLabel.Text);
d = c.CandidateTable.Data;
for r = 1:size(d, 1)
    fprintf('  %s\n', strjoin(cellfun(@(v) num2str(v), d(r, :), 'UniformOutput', false), ' | '));
end
info = plainLines(c.IdentInfo.HTMLSource);
fprintf('%s\n', info{:});
fprintf('readings tab: %s\n', c.IdentReadingsTab.Title);
delete(app);
end

function lines = plainLines(html)
% The text of an information box (INFOPANELHTML), one line per heading, bullet or paragraph.
html = regexprep(html, '<style>.*</style>', '');
html = regexprep(html, '</(li|p|h4)>', '\n');
text = regexprep(html, '<[^>]*>', '');
text = strrep(strrep(strrep(strrep(text, '&lt;', '<'), '&gt;', '>'), '&#9888;&#65038;', '[!]'), '&#10004;&#65038;', '[ok]');
text = strrep(text, '&amp;', '&');
lines = strtrim(regexp(text, '\n', 'split'));
lines = lines(~cellfun(@isempty, lines));
end

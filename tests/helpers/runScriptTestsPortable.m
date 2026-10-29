function summary = runScriptTestsPortable(testDir)
%RUNSCRIPTTESTSPORTABLE Run MATLAB script-based test files without matlab.unittest.
%   SUMMARY = RUNSCRIPTTESTSPORTABLE(TESTDIR) runs every TESTDIR/test*.m
%   file with the semantics of MATLAB script-based unit tests: the code
%   before the first '%%' line is shared setup, and each '%%' section is a
%   separate test that runs in a fresh workspace after the shared setup. A
%   test passes if the setup and its section run without error. SUMMARY is
%   a struct array with fields file, name, passed and message.
%
%   Used on GNU Octave, which has no matlab.unittest. Test files must not
%   define local functions or use variable names starting with 'zz'.
%
%   See also RUNALLTESTS.

files = dir(fullfile(testDir, 'test*.m'));
summary = struct('file', {}, 'name', {}, 'passed', {}, 'message', {});
for f = 1:numel(files)
    [~, fileName] = fileparts(files(f).name);
    text = fileread(fullfile(testDir, files(f).name));
    lines = regexp(text, '\r?\n', 'split');
    isHeader = ~cellfun(@isempty, regexp(lines, '^\s*%%(\s|$)', 'once'));
    starts = find(isHeader);
    if isempty(starts)
        lines = [{'%% (whole file)'}, lines];
        starts = 1;
    end
    setupCode = strjoin(lines(1:starts(1)-1), char(10));
    for s = 1:numel(starts)
        if s < numel(starts)
            stop = starts(s+1) - 1;
        else
            stop = numel(lines);
        end
        testName = strtrim(regexprep(lines{starts(s)}, '^\s*%%', ''));
        bodyCode = strjoin(lines(starts(s)+1:stop), char(10));
        fprintf('\n=== %s / %s ===\n', fileName, testName);
        [passed, message] = runSection(setupCode, bodyCode);
        if passed
            fprintf('--- PASS\n');
        else
            fprintf('--- FAIL: %s\n', message);
        end
        summary(end+1) = struct('file', fileName, 'name', testName, ...
            'passed', passed, 'message', message); %#ok<AGROW>
    end
end
end

function [zzPassed, zzMessage] = runSection(zzSetupCode, zzBodyCode)
% Runs in its own workspace so tests cannot see each other's variables.
try
    eval(zzSetupCode);
    eval(zzBodyCode);
    zzPassed = true;
    zzMessage = '';
catch zzErr
    zzPassed = false;
    zzMessage = sprintf('%s [%s]', zzErr.message, zzErr.identifier);
end
end

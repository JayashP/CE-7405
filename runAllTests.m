function summary = runAllTests()
%RUNALLTESTS Run every test in tests/ (MATLAB or GNU Octave) and print a summary.
%   SUMMARY = RUNALLTESTS() adds the project paths, runs all tests/test*.m
%   files, prints each test's PASS/FAIL status, and returns a struct array
%   with fields file, name, passed and message. After printing, it throws
%   'BridgeFE:testsFailed' if any test failed, so a command-line run exits
%   with a nonzero status.
%
%   The test files are MATLAB script-based unit tests: the code before the
%   first '%%' line is shared setup and each '%%' section is one test.
%     MATLAB:      run by the matlab.unittest framework.
%     GNU Octave:  matlab.unittest does not exist, so the same files run
%                  through RUNSCRIPTTESTSPORTABLE with the same semantics.
%
%   Command line, from the repository root:
%     matlab -batch "runAllTests"
%     octave-cli --eval "runAllTests"

root = addProjectPaths();
testDir = fullfile(root, 'tests');
isOctave = exist('OCTAVE_VERSION', 'builtin') ~= 0;

if isOctave
    platform = ['GNU Octave ' OCTAVE_VERSION];
    summary = runScriptTestsPortable(testDir);
else
    platform = ['MATLAB ' version];
    addpath(testDir);
    suite = matlab.unittest.TestSuite.fromFolder(testDir);
    runner = matlab.unittest.TestRunner.withTextOutput;
    testResults = runner.run(suite);
    summary = struct('file', {}, 'name', {}, 'passed', {}, 'message', {});
    for k = 1:numel(testResults)
        fullName = testResults(k).Name;
        slash = find(fullName == '/', 1);
        if isempty(slash)
            fileName = fullName;
            testName = fullName;
        else
            fileName = fullName(1:slash-1);
            testName = fullName(slash+1:end);
        end
        message = '';
        if ~testResults(k).Passed
            message = 'see the matlab.unittest diagnostics printed above';
        end
        summary(end+1) = struct('file', fileName, 'name', testName, ...
            'passed', logical(testResults(k).Passed), 'message', message); %#ok<AGROW>
    end
end

nPassed = nnz([summary.passed]);
nFailed = numel(summary) - nPassed;
fprintf('\n==================== TEST SUMMARY ====================\n');
fprintf('Platform : %s\n', platform);
fprintf('Date     : %s\n', datestr(now, 'yyyy-mm-dd HH:MM:SS'));
for k = 1:numel(summary)
    if summary(k).passed
        status = 'PASS';
    else
        status = 'FAIL';
    end
    fprintf('  %s  %s / %s\n', status, summary(k).file, summary(k).name);
    if ~summary(k).passed && ~isempty(summary(k).message)
        fprintf('        %s\n', summary(k).message);
    end
end
fprintf('Total: %d passed, %d failed, %d tests\n', nPassed, nFailed, numel(summary));
fprintf('======================================================\n');

if nFailed > 0
    error('BridgeFE:testsFailed', '%d of %d tests failed.', nFailed, numel(summary));
end
if nargout == 0
    clear summary   % no 'ans = 1xN struct array' echo when called as a command
end
end

function runGuiMockCheck(includeVerification)
%RUNGUIMOCKCHECK Run tests/gui/checkBridgeConditionApp in GNU Octave with stand-in UI components.
%   RUNGUIMOCKCHECK() puts tools/gui_mock first on the path, so the app's
%   uifigure, uigridlayout, uieditfield, ... calls and plot/patch/text on
%   UIAxes go to stand-ins that check property names, Layout use, colours,
%   value limits and plot arguments against the real components. It then
%   runs the same scripted app check that is run in MATLAB.
%   It shows that the app code runs and is wired to the engine. It does NOT
%   show how MATLAB renders the window: that needs the MATLAB run.
%   RUNGUIMOCKCHECK(true) also presses "Run all tests" inside the app.
%
%   octave-cli --eval "addpath('tools/gui_mock'); runGuiMockCheck"

if nargin < 1
    includeVerification = false;
end
here = fileparts(mfilename('fullpath'));
root = fileparts(fileparts(here));
addpath(root);
addProjectPaths();
warning('off', 'Octave:shadowed-function');
addpath(here, '-begin');
checkBridgeConditionApp(includeVerification);
end

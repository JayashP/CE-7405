function root = addProjectPaths()
%ADDPROJECTPATHS Put the project's source, app and test-helper folders on the path.
%   ROOT = ADDPROJECTPATHS() adds src/ (with subfolders), app/,
%   tests/helpers/ and tests/gui/ to the MATLAB or GNU Octave path and
%   returns the repository root. Then start the app with BRIDGECONDITIONAPP.

root = fileparts(mfilename('fullpath'));
addpath(genpath(fullfile(root, 'src')));
addpath(fullfile(root, 'app'));
addpath(fullfile(root, 'tests', 'helpers'));
addpath(fullfile(root, 'tests', 'gui'));
end

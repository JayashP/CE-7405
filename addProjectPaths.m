function root = addProjectPaths()
%ADDPROJECTPATHS Put the project's source and test-helper folders on the path.
%   ROOT = ADDPROJECTPATHS() adds src/ (with subfolders) and tests/helpers/
%   to the MATLAB or GNU Octave path and returns the repository root.

root = fileparts(mfilename('fullpath'));
addpath(genpath(fullfile(root, 'src')));
addpath(fullfile(root, 'tests', 'helpers'));
end

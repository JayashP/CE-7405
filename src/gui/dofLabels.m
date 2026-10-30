function labels = dofLabels(nn)
%DOFLABELS Names of the global DOFs: {'v1', 'theta1', 'v2', 'theta2', ...}.
%   LABELS = DOFLABELS(NN) returns a 1-by-2NN cellstr for NN nodes, using
%   the Greek letter theta (char(952)) for rotations in MATLAB. GNU Octave
%   stores characters as single bytes, so it uses the word 'theta' instead.
%
%   See also ELEMENTDOFS.

theta = 'theta';
if ~exist('OCTAVE_VERSION', 'builtin')
    theta = char(952);
end
labels = cell(1, 2 * nn);
for n = 1:nn
    labels{2*n - 1} = sprintf('v%d', n);
    labels{2*n} = sprintf('%s%d', theta, n);
end
end

%OPENBRIDGEAPP Open the CE 7405 bridge analysis app (press Run, or type openBridgeApp).
%   One step for MATLAB Online or MATLAB desktop: puts the project folders on the
%   path and opens BridgeConditionApp with its built-in example (one 20 m steel span,
%   pin and roller, the illustrative 3-axle truck 80, 120, 120 kN).
%
%   Try it in one minute:
%     1. Envelopes tab: press "Run moving-load analysis"
%        (expect M max = 1349.102 kN*m at x = 9.740 m).
%     2. Damage (Stage 2) tab: press "Apply damage", then
%        "Compare healthy vs damaged (moving load)".
%     3. Identification (Stage 3) tab: press "Generate synthetic readings",
%        then "Run identification".
%
%   See also BRIDGECONDITIONAPP, ADDPROJECTPATHS.

here = fileparts(mfilename('fullpath'));
if isempty(here)                        % run as a selection: use the current folder
    here = pwd;
end
addpath(here);
addProjectPaths;
app = BridgeConditionApp;
fprintf(['CE 7405 bridge app opened. Try: Envelopes tab -> "Run moving-load analysis" ', ...
    '(M max = 1349.102 kN*m at x = 9.740 m).\n']);

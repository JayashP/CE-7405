%TESTMESHSPANSANDLOADS Span-based meshing, element selection and uniform-load vectors.
%   Script-based test file (see runAllTests). Expected coordinates and load
%   vectors are hand-written literals; the consistent load vector is also
%   checked against direct Gauss integration of w times the Hermite shape
%   functions, independently of equivalentDistributedLoad.
roundoffPct = 1e-10;

%% Two equal spans give the hand-written coordinates with a node at every support
[x, xs] = meshSpans([10 10], 4);
fprintf('  x = %s\n  xSupports = %s\n', mat2str(x.'), mat2str(xs.'));
assert(isequal(x, [0; 2.5; 5; 7.5; 10; 12.5; 15; 17.5; 20]), 'meshSpans([10 10], 4) coordinates are wrong');
assert(isequal(xs, [0; 10; 20]), 'support coordinates should be [0; 10; 20]');
fprintf('  PASS meshSpans([10 10], 4) matches the hand-written coordinates exactly\n');

%% Unequal spans with different element counts keep every support on a node
[x, xs] = meshSpans([10 15], [4 3]);
fprintf('  x = %s\n  xSupports = %s\n', mat2str(x.'), mat2str(xs.'));
assert(isequal(x, [0; 2.5; 5; 7.5; 10; 15; 20; 25]), 'meshSpans([10 15], [4 3]) coordinates are wrong');
assert(isequal(xs, [0; 10; 25]), 'support coordinates should be [0; 10; 25]');
[x, xs] = meshSpans([7.3 11.9 4.15], [7 13 5]);
model = createBeamModel(x, 2e9);
for k = 1:numel(xs)
    n = findNodeAtX(model, xs(k));
    assert(x(n) == xs(k), 'support coordinate %g is not exactly a node', xs(k));
end
fprintf('  PASS every support coordinate of spans [7.3 11.9 4.15] is exactly a node (%d nodes)\n', numel(x));

%% Invalid span input is rejected
assertThrows(@() meshSpans([10 -5], 4), 'BridgeFE:invalidInput');
assertThrows(@() meshSpans([10 10], [4 0]), 'BridgeFE:invalidInput');
assertThrows(@() meshSpans([10 10], [4 4 4]), 'BridgeFE:invalidInput');
assertThrows(@() meshSpans([10 10], 2.5), 'BridgeFE:invalidInput');

%% elementsBetween selects the elements of one span and refuses off-node limits
model = createBeamModel(meshSpans([10 10], 4), 2e9);
assert(isequal(elementsBetween(model, 0, 10), (1:4)'), 'span 1 should be elements 1-4');
assert(isequal(elementsBetween(model, 10, 20), (5:8)'), 'span 2 should be elements 5-8');
assert(isequal(elementsBetween(model, 7.5, 12.5), [4; 5]), 'x = 7.5..12.5 should be elements 4-5');
fprintf('  PASS span 1 -> elements 1-4, span 2 -> elements 5-8, 7.5..12.5 m -> elements 4-5\n');
assertThrows(@() elementsBetween(model, 0, 11), 'BridgeFE:notOnNode');
assertThrows(@() elementsBetween(model, 10, 10), 'BridgeFE:invalidInput');

%% Consistent uniform-load vector matches hand-written values
% w = -12 kN/m (downward), Le = 2 m: wLe/2 = -12000 N, wLe^2/12 = -4000 N*m.
fe0 = equivalentDistributedLoad(-12e3, 2);
fprintf('  fe0 = %s\n', mat2str(fe0.'));
reportComparisons('Consistent load vector, w = -12 kN/m, Le = 2 m', [ ...
    compareToReference('F1 = wLe/2 [N]', fe0(1), -12e3, roundoffPct), ...
    compareToReference('M1 = wLe^2/12 [N*m]', fe0(2), -4e3, roundoffPct), ...
    compareToReference('F2 = wLe/2 [N]', fe0(3), -12e3, roundoffPct), ...
    compareToReference('M2 = -wLe^2/12 [N*m]', fe0(4), 4e3, roundoffPct)]);
assertThrows(@() equivalentDistributedLoad(NaN, 2), 'BridgeFE:invalidInput');
assertThrows(@() equivalentDistributedLoad(-12e3, 0), 'BridgeFE:invalidInput');

%% Consistent load vector equals Gauss integration of w*N over the element
w = -7.5e3;
Le = 1.37;
gaussPoints = [-sqrt(3/5); 0; sqrt(3/5)];       % 3-point rule, exact for quintic integrands
gaussWeights = [5/9; 8/9; 5/9];
r = (gaussPoints + 1) / 2;                       % map [-1, 1] -> [0, 1]
N = [1 - 3*r.^2 + 2*r.^3, Le*(r - 2*r.^2 + r.^3), 3*r.^2 - 2*r.^3, Le*(-r.^2 + r.^3)];
fGauss = (w * (Le/2) * (gaussWeights.' * N)).';
fe0 = equivalentDistributedLoad(w, Le);
reportComparisons('Consistent load vector vs integral of w*N_i, w = -7.5 kN/m, Le = 1.37 m', ...
    compareToReference('max|fe0 - integral| / max|integral| [-]', max(abs(fe0 - fGauss)) / max(abs(fGauss)), 0, [], 1e-14));

%% Uniform loads superpose and assemble into the hand-written global vector
model = createBeamModel([0; 1; 2], 1);
model = addUniformLoad(model, -4);
model = addUniformLoad(model, -2, [1 2]);
F = assembleLoadVector(model);
expected = [-3; -0.5; -6; 0; -3; 0.5];
fprintf('  elementUDL = %s, F = %s\n', mat2str(model.loads.elementUDL.'), mat2str(F.', 6));
assert(isequal(model.loads.elementUDL, [-6; -6]), 'superposed element loads should be [-6; -6]');
assert(max(abs(F - expected)) <= 1e-14, 'assembled F differs from the hand-written vector');
fprintf('  PASS assembled F equals the hand-written vector\n');

%% Assembled uniform load keeps the resultant force and moment on a nonuniform mesh
x = [0; 0.7; 2.2; 2.5; 4.9; 6];
w = -15e3;
model = addUniformLoad(createBeamModel(x, 2e9), w);
model = addNodalLoad(model, 3, -8e3, 2e3);
F = assembleLoadVector(model);
Fv = F(1:2:end);
Mz = F(2:2:end);
L = x(end);
reportComparisons('Resultants of the assembled load vector, w = -15 kN/m over 6 m plus a nodal load', [ ...
    compareToReference('sum Fv [kN]', sum(Fv)/1e3, (w*L - 8e3)/1e3, roundoffPct), ...
    compareToReference('sum moment about x = 0 [kN*m]', (sum(Fv .* x) + sum(Mz))/1e3, (w*L^2/2 - 8e3*x(3) + 2e3)/1e3, roundoffPct)]);

%% Invalid uniform-load input is rejected
model = createBeamModel([0; 1; 2], 1);
assertThrows(@() addUniformLoad(model, Inf), 'BridgeFE:invalidInput');
assertThrows(@() addUniformLoad(model, -1, 3), 'BridgeFE:invalidInput');
assertThrows(@() addUniformLoad(model, -1, 1.5), 'BridgeFE:invalidInput');
broken = model;
broken.loads.elementUDL = [1; 2; 3];
assertThrows(@() assembleLoadVector(broken), 'BridgeFE:invalidModel');

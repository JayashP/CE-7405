%TESTSHAPEFUNCTIONSANDPOINTLOADS Hermite shape functions, point-load vectors and load location.
%   Script-based test file (see runAllTests). Expected values are hand-
%   computed fractions or textbook fixed-end actions (P*a*b^2/L^2,
%   P*a^2*b/L^2), independent of the implementation.
roundoffPct = 1e-10;

%% Shape functions take nodal values and reproduce rigid-body motion
Le = 2.5;
assert(isequal(beamShapeFunctions(0, Le), [1 0 0 0]), 'N(r = 0) must be [1 0 0 0]');
assert(isequal(beamShapeFunctions(1, Le), [0 0 1 0]), 'N(r = 1) must be [0 0 1 0]');
r = linspace(0, 1, 101)';
N = beamShapeFunctions(r, Le);
reportComparisons('Hermite shape functions, Le = 2.5 m, 101 points', [ ...
    compareToReference('max|N1 + N3 - 1| [-] (vertical translation)', max(abs(N(:, 1) + N(:, 3) - 1)), 0, [], 1e-14), ...
    compareToReference('max|N2 + Le*N3 + N4 - s| [m] (rigid rotation)', max(abs(N(:, 2) + Le*N(:, 3) + N(:, 4) - Le*r)), 0, [], 1e-14)]);

%% Shape functions at r = 1/3 match hand-computed fractions
Le = 3;
N = beamShapeFunctions(1/3, Le);
fprintf('  N(1/3) = %s\n', mat2str(N, 12));
reportComparisons('Shape functions at r = 1/3, Le = 3 m', [ ...
    compareToReference('N1 = 20/27 [-]', N(1), 20/27, roundoffPct), ...
    compareToReference('N2 = 4Le/27 [m]', N(2), 4*Le/27, roundoffPct), ...
    compareToReference('N3 = 7/27 [-]', N(3), 7/27, roundoffPct), ...
    compareToReference('N4 = -2Le/27 [m]', N(4), -2*Le/27, roundoffPct)]);

%% Shape-function slopes at the element ends select the nodal rotations
Le = 1.7;
h = 1e-6;
d0 = (beamShapeFunctions(h, Le) - beamShapeFunctions(0, Le)) / (h * Le);       % dN/ds at s = 0
d1 = (beamShapeFunctions(1, Le) - beamShapeFunctions(1 - h, Le)) / (h * Le);   % dN/ds at s = Le
fprintf('  dN/ds(0) = %s\n  dN/ds(Le) = %s\n', mat2str(d0, 6), mat2str(d1, 6));
reportComparisons('Finite-difference slopes of N at the element ends (step 1e-6*Le)', [ ...
    compareToReference('max|dN/ds(0) - [0 1 0 0]| [-]', max(abs(d0 - [0 1 0 0])), 0, [], 1e-5), ...
    compareToReference('max|dN/ds(Le) - [0 0 0 1]| [-]', max(abs(d1 - [0 0 0 1])), 0, [], 1e-5)]);

%% Point-load vector equals the textbook fixed-end actions
P = -100e3;
Le = 3;
f = equivalentPointLoad(P, Le/2, Le);
g = equivalentPointLoad(P, Le/3, Le);
a = Le/3;
b = 2*Le/3;
fprintf('  midspan: %s\n  third point: %s\n', mat2str(f.', 10), mat2str(g.', 10));
reportComparisons('Consistent point-load vectors, P = -100 kN, Le = 3 m', [ ...
    compareToReference('midspan F1 = P/2 [N]', f(1), P/2, roundoffPct), ...
    compareToReference('midspan M1 = P*Le/8 [N*m]', f(2), P*Le/8, roundoffPct), ...
    compareToReference('midspan F2 = P/2 [N]', f(3), P/2, roundoffPct), ...
    compareToReference('midspan M2 = -P*Le/8 [N*m]', f(4), -P*Le/8, roundoffPct), ...
    compareToReference('a = Le/3: M1 = P*a*b^2/Le^2 [N*m]', g(2), P*a*b^2/Le^2, roundoffPct), ...
    compareToReference('a = Le/3: M2 = -P*a^2*b/Le^2 [N*m]', g(4), -P*a^2*b/Le^2, roundoffPct), ...
    compareToReference('a = Le/3: F1 = P*b^2*(3a + b)/Le^3 [N]', g(1), P*b^2*(3*a + b)/Le^3, roundoffPct), ...
    compareToReference('a = Le/3: F2 = P*a^2*(a + 3b)/Le^3 [N]', g(3), P*a^2*(a + 3*b)/Le^3, roundoffPct)]);
assert(isequal(equivalentPointLoad(P, 0, Le), [P; 0; 0; 0]), 'a load at a = 0 must go wholly to v1');
assert(isequal(equivalentPointLoad(P, Le, Le), [0; 0; P; 0]), 'a load at a = Le must go wholly to v2');
fprintf('  PASS a = 0 -> [P 0 0 0], a = Le -> [0 0 P 0] exactly\n');

%% Point-load vector keeps the resultant force and moment for any position
P = -73e3;
Le = 2.2;
aList = [0.05 0.4 1.1 1.73 2.19];
rows = [];
for a = aList
    f = equivalentPointLoad(P, a, Le);
    rows = [rows, ...
        compareToReference(sprintf('a = %.2f m: F1 + F2 [kN]', a), (f(1) + f(3))/1e3, P/1e3, roundoffPct), ...
        compareToReference(sprintf('a = %.2f m: M1 + M2 + F2*Le [kN*m]', a), (f(2) + f(4) + f(3)*Le)/1e3, P*a/1e3, roundoffPct)]; %#ok<AGROW>
end
reportComparisons('Resultant of the consistent point-load vector (about the left node)', rows);

%% Point loads at nodes are nodal loads and interior loads keep their position
model = createBeamModel(generateUniformMesh(10, 4), 2e9);
xLoads = [0, 2.5, 2.5 + 1e-12, 3.7, 9.9, 10];
for k = 1:numel(xLoads)
    model = addPointLoad(model, xLoads(k), -k * 1e3);
end
loc = locatePointLoads(model);
fprintf('  %10s %6s %8s %10s\n', 'x [m]', 'node', 'element', 'a [m]');
fprintf('  %10.12g %6d %8d %10.6g\n', [loc.x, loc.node, loc.element, loc.a].');
assert(isequal(loc.node, [1; 2; 2; 0; 0; 5]), 'node assignment is wrong');
assert(isequal(loc.element, [0; 0; 0; 2; 4; 0]), 'element assignment is wrong');
assert(abs(loc.a(4) - 1.2) < 1e-12 && abs(loc.a(5) - 2.4) < 1e-12, 'local positions should be 1.2 m and 2.4 m');
fprintf('  PASS loads at 0, 2.5 and 10 m -> nodes 1, 2, 5; 2.5 m + 1e-12 -> node 2 (round-off only);\n');
fprintf('       3.7 m -> element 2 at a = 1.2 m; 9.9 m -> element 4 at a = 2.4 m\n');

%% Assembled F is the nodal load at a node and the Hermite vector inside an element
base = createBeamModel(generateUniformMesh(10, 4), 2e9);
Fa = assembleLoadVector(addPointLoad(base, 5, -40e3));
Fb = assembleLoadVector(addNodalLoad(base, 3, -40e3));
assert(isequal(Fa, Fb), 'a point load at a node must equal the same nodal load');
F = assembleLoadVector(addPointLoad(base, 6.1, -40e3));
expected = zeros(10, 1);
expected(5:8) = equivalentPointLoad(-40e3, 6.1 - 5, 2.5);
assert(max(abs(F - expected)) <= 1e-9, 'interior point load must be the Hermite vector of element 3');
fprintf('  PASS point load at a node == nodal load; at 6.1 m == Hermite vector on DOFs 5-8\n');

%% Invalid shape-function and point-load input is rejected
assertThrows(@() beamShapeFunctions(1.1, 2), 'BridgeFE:invalidInput');
assertThrows(@() beamShapeFunctions(-0.1, 2), 'BridgeFE:invalidInput');
assertThrows(@() equivalentPointLoad(-1e3, 2.6, 2.5), 'BridgeFE:invalidInput');
assertThrows(@() equivalentPointLoad(NaN, 1, 2.5), 'BridgeFE:invalidInput');
model = createBeamModel(generateUniformMesh(10, 4), 2e9);
assertThrows(@() addPointLoad(model, 10.5, -1e3), 'BridgeFE:offBeam');
assertThrows(@() addPointLoad(model, -0.01, -1e3), 'BridgeFE:offBeam');
assertThrows(@() addPointLoad(model, 3, Inf), 'BridgeFE:invalidInput');
broken = model;
broken.loads.point = [12, -1e3];
assertThrows(@() assembleLoadVector(broken), 'BridgeFE:invalidModel');

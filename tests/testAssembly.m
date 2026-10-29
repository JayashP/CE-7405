%TESTASSEMBLY Unit tests for the DOF map, global stiffness and nodal load assembly.
%   Script-based test file (see runAllTests). Reference matrices are written
%   by hand or built with explicit Boolean A_e matrices (K = sum A_e'*k_e*A_e),
%   independently of the triplet assembly in assembleGlobalK.
roundoffPct = 1e-10;

%% Element DOF map is [v_i theta_i v_j theta_j] with node n owning DOFs 2n-1 and 2n
dofMap = elementDofs([1 2; 2 3; 3 4]);
expected = [1 2 3 4; 3 4 5 6; 5 6 7 8];
disp(dofMap);
assert(isequal(dofMap, expected), 'elementDofs does not match the hand-written DOF map');
fprintf('  PASS elementDofs matches the hand-written DOF map\n');

%% Two equal unit elements assemble to the hand-computed 6x6 matrix
model = createBeamModel([0; 1; 2], 1);
K = full(assembleGlobalK(model));
expected = [ 12   6  -12   6    0   0
              6   4   -6   2    0   0
            -12  -6   24   0  -12   6
              6   2    0   8   -6   2
              0   0  -12  -6   12  -6
              0   0    6   2   -6   4 ];
disp(K);
assert(isequal(K, expected), 'Assembled K for two unit elements differs from the hand-computed matrix');
fprintf('  PASS two-element K equals the hand-computed matrix exactly\n');

%% Unequal lengths and EI match K = sum(A_e'*k_e*A_e) with explicit Boolean A_e
x = [0; 2; 5; 5.5];
EI = [3e9; 1e9; 2.5e9];
model = createBeamModel(x, EI);
K = full(assembleGlobalK(model));
handDofs = [1 2 3 4; 3 4 5 6; 5 6 7 8];
Kref = zeros(8);
for e = 1:3
    A = zeros(4, 8);
    for a = 1:4
        A(a, handDofs(e, a)) = 1;
    end
    Kref = Kref + A' * beamElementStiffness(EI(e), x(e+1) - x(e)) * A;
end
relErr = max(abs(K(:) - Kref(:))) / max(abs(Kref(:)));
reportComparisons('Nonuniform 3-element beam: triplet assembly vs explicit A_e assembly', ...
    compareToReference('max|K - Kref| / max|Kref| [-]', relErr, 0, [], 1e-14));

%% Assembled K is symmetric with exactly two rigid-body modes
L = 30;
x = generateUniformMesh(L, 20);
nn = numel(x);
model = createBeamModel(x, 2e9);
K = full(assembleGlobalK(model));
scale = max(abs(K(:)));
translation = repmat([1; 0], nn, 1);                 % v = 1, theta = 0
rotation = reshape([x.'; ones(1, nn)], [], 1);       % v = x, theta = 1
reportComparisons('Global K, 30 m beam, 20 elements, 21 nodes, no supports', [ ...
    compareToReference('number of DOFs [-]', size(K, 1), 42, roundoffPct), ...
    compareToReference('max|K - K''| / max|K| [-]', max(max(abs(K - K.'))) / scale, 0, [], 1e-15), ...
    compareToReference('rank(K) [-] (DOFs - 2 rigid modes)', rank(K), 2*nn - 2, roundoffPct), ...
    compareToReference('max|K*translation| / max|K| [-]', max(abs(K * translation)) / scale, 0, [], 1e-12), ...
    compareToReference('max|K*rotation| / (max|K|*L) [-]', max(abs(K * rotation)) / (scale * L), 0, [], 1e-12)]);

%% Nodal load vector puts forces at v DOFs and couples at theta DOFs and sums repeats
model = createBeamModel(generateUniformMesh(4, 4), 2e9);
model = addNodalLoad(model, 2, -1000);
model = addNodalLoad(model, 2, -500, 0);
model = addNodalLoad(model, 4, 0, 250);
model = addNodalLoad(model, 5, 300, -40);
F = assembleNodalLoadVector(model);
expected = [0; 0; -1500; 0; 0; 0; 0; 250; 300; -40];
fprintf('  F = %s\n', mat2str(F.'));
assert(isequal(F, expected), 'Nodal load vector differs from the hand-written vector');
fprintf('  PASS nodal load vector equals the hand-written vector\n');

%% Invalid model data are rejected
assertThrows(@() createBeamModel([0; 1; 1], 1), 'BridgeFE:invalidInput');          % zero-length element
assertThrows(@() createBeamModel([0; 2; 1], 1), 'BridgeFE:invalidInput');          % reversed nodes
assertThrows(@() createBeamModel(0, 1), 'BridgeFE:invalidInput');                  % single node
assertThrows(@() createBeamModel([0; 1; 2], [1; -1]), 'BridgeFE:invalidInput');    % negative EI
assertThrows(@() createBeamModel([0; 1; 2], [1; 2; 3]), 'BridgeFE:invalidInput');  % EI count mismatch
assertThrows(@() generateUniformMesh(20, 2.5), 'BridgeFE:invalidInput');
assertThrows(@() generateUniformMesh(-20, 4), 'BridgeFE:invalidInput');
model = createBeamModel([0; 1; 2], 1);
broken = model;
broken.elements.EI(2) = 0;
assertThrows(@() assembleGlobalK(broken), 'BridgeFE:invalidModel');
broken = model;
broken.elements.conn = [1 3; 2 3];
assertThrows(@() assembleGlobalK(broken), 'BridgeFE:invalidModel');
assertThrows(@() addNodalLoad(model, 4, -1), 'BridgeFE:invalidInput');
assertThrows(@() addNodalLoad(model, 2, NaN), 'BridgeFE:invalidInput');

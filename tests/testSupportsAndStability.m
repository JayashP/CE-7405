%TESTSUPPORTSANDSTABILITY Support mapping, DOF partition and under-restraint detection.
%   Script-based test file (see runAllTests). The stability rule in
%   partitionDofs is cross-checked against the numerical rank of Kff.

%% Pin and roller restrain v only and fixed restrains v and theta
assert(isequal(supportRestraint('pin'), [true false]), 'pin must restrain v only');
assert(isequal(supportRestraint('Roller'), [true false]), 'roller must restrain v only');
assert(isequal(supportRestraint('FIXED'), [true true]), 'fixed must restrain v and theta');
fprintf('  PASS pin -> [v], roller -> [v], fixed -> [v theta]\n');

%% Simply supported 4-element beam restrains v at the two end nodes only
model = createBeamModel(generateUniformMesh(20, 4), 2e9);
model = addSupport(model, 1, 'pin');
model = addSupport(model, 5, 'roller');
[freeDofs, restrainedDofs] = partitionDofs(model);
fprintf('  restrained DOFs %s, free DOFs %s\n', mat2str(restrainedDofs.'), mat2str(freeDofs.'));
assert(isequal(restrainedDofs, [1; 9]), 'restrained DOFs should be [1; 9]');
assert(isequal(freeDofs, [2; 3; 4; 5; 6; 7; 8; 10]), 'free DOFs should be [2..8, 10]');

%% Fixed end plus roller (propped-cantilever layout) restrains v1, theta1 and v5
model = createBeamModel(generateUniformMesh(20, 4), 2e9);
model = addSupport(model, 1, 'fixed');
model = addSupport(model, 5, 'roller');
[freeDofs, restrainedDofs] = partitionDofs(model);
fprintf('  restrained DOFs %s, free DOFs %s\n', mat2str(restrainedDofs.'), mat2str(freeDofs.'));
assert(isequal(restrainedDofs, [1; 2; 9]), 'restrained DOFs should be [1; 2; 9]');

%% Under-restrained models are rejected with BridgeFE:underRestrained
model = createBeamModel(generateUniformMesh(20, 4), 2e9);
model = addNodalLoad(model, 3, -100e3);
assertThrows(@() partitionDofs(model), 'BridgeFE:underRestrained');           % no supports
assertThrows(@() solveStaticModel(model), 'BridgeFE:underRestrained');
onePin = addSupport(model, 1, 'pin');
assertThrows(@() partitionDofs(onePin), 'BridgeFE:underRestrained');          % rotation about the pin free
assertThrows(@() solveStaticModel(onePin), 'BridgeFE:underRestrained');
oneInteriorRoller = addSupport(model, 3, 'roller');
assertThrows(@() solveStaticModel(oneInteriorRoller), 'BridgeFE:underRestrained');

%% Stability rule agrees with the numerical rank of Kff for many support layouts
base = createBeamModel(generateUniformMesh(20, 4), 2e9);
K = full(assembleGlobalK(base));
layouts = {{}, {1, 'pin'}, {3, 'roller'}, {5, 'fixed'}, {1, 'pin', 5, 'roller'}, ...
    {2, 'pin', 4, 'roller'}, {1, 'fixed', 5, 'roller'}, {1, 'fixed', 5, 'fixed'}, ...
    {3, 'fixed'}, {1, 'pin', 2, 'pin', 3, 'roller'}};
for k = 1:numel(layouts)
    layout = layouts{k};
    model = base;
    label = '';
    for s = 1:2:numel(layout)
        model = addSupport(model, layout{s}, layout{s+1});
        label = [label, sprintf('%s@node%d ', layout{s+1}, layout{s})]; %#ok<AGROW>
    end
    if isempty(label)
        label = 'none';
    end
    restrained = false(size(K, 1), 1);
    for s = 1:numel(model.supports.node)
        n = model.supports.node(s);
        restrained([2*n - 1, 2*n]) = model.supports.restraint(s, :);
    end
    Kff = K(~restrained, ~restrained);
    numericallyStable = rank(Kff) == size(Kff, 1);
    ruleStable = true;
    try
        partitionDofs(model);
    catch err
        ruleStable = false;
        assert(strcmp(err.identifier, 'BridgeFE:underRestrained'), 'unexpected error %s', err.identifier);
    end
    fprintf('  %-34s rank(Kff) = %d of %d   rule stable = %d   numerically stable = %d\n', ...
        label, rank(Kff), size(Kff, 1), ruleStable, numericallyStable);
    assert(ruleStable == numericallyStable, 'Stability rule disagrees with rank(Kff) for layout %s', label);
end

%% Duplicate, unknown-type and off-range supports are rejected
model = createBeamModel(generateUniformMesh(20, 4), 2e9);
model = addSupport(model, 1, 'pin');
assertThrows(@() addSupport(model, 1, 'roller'), 'BridgeFE:duplicateSupport');
assertThrows(@() addSupport(model, 2, 'hinge'), 'BridgeFE:invalidSupportType');
assertThrows(@() addSupport(model, 6, 'pin'), 'BridgeFE:invalidInput');
assertThrows(@() addSupport(model, 2.5, 'pin'), 'BridgeFE:invalidInput');
broken = model;
broken.supports.restraint(1, 2) = true;      % a 'pin' wrongly flagged as rotation-restrained
assertThrows(@() partitionDofs(broken), 'BridgeFE:invalidModel');

%% Coordinates map to nodes only where a node exists
model = createBeamModel(generateUniformMesh(20, 20), 2e9);
assert(findNodeAtX(model, 0) == 1, 'x = 0 should be node 1');
assert(findNodeAtX(model, 10) == 11, 'x = 10 m should be node 11');
assert(findNodeAtX(model, 20) == 21, 'x = 20 m should be node 21');
fprintf('  PASS x = 0, 10, 20 m map to nodes 1, 11, 21\n');
assertThrows(@() findNodeAtX(model, 10.3), 'BridgeFE:notOnNode');
assertThrows(@() findNodeAtX(model, -1), 'BridgeFE:notOnNode');

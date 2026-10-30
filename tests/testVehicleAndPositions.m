%TESTVEHICLEANDPOSITIONS Vehicle definition, axle coordinates, position grid and on-bridge policy.
%   Script-based test file (see runAllTests). Uses the illustrative 3-axle
%   truck of PROJECT_SPEC.md section 5.1 (80, 120, 120 kN; spacings 4.2 m and
%   1.4 m; front axle is the reference). Expected coordinates and reactions
%   are hand-computed from statics.
L = 20;            % [m]
EI = 200e9 * 0.01; % [N*m^2]
tol = 0.1;         % [%]
truck = createVehicle([80e3 120e3 120e3], [4.2 1.4], 'spec 3-axle example');

%% Axle coordinates follow the front-axle reference in both directions
[xa, Pa] = vehicleAxlePositions(truck, 10, 1);
[xb, ~] = vehicleAxlePositions(truck, 10, -1);
fprintf('  +x: axles at %s m, forces %s N\n  -x: axles at %s m\n', mat2str(xa.', 6), mat2str(Pa.'), mat2str(xb.', 6));
assert(max(abs(xa - [10; 5.8; 4.4])) < 1e-12, 'toward +x the axles should be at 10, 5.8, 4.4 m');
assert(max(abs(xb - [10; 14.2; 15.6])) < 1e-12, 'toward -x the axles should be at 10, 14.2, 15.6 m');
assert(isequal(Pa, [-80e3; -120e3; -120e3]), 'axle forces should be negative (downward)');
fprintf('  PASS axle coordinates and signed forces\n');

%% Position grid runs from first entry to full exit with an exact step
model = createBeamModel(generateUniformMesh(L, 8), EI);
[xv, h] = generateVehiclePositions(model, truck, 0.1, 1);
fprintf('  +x: %d positions from %g to %g m, step %.12g m\n', numel(xv), xv(1), xv(end), h);
assert(numel(xv) == 257 && xv(1) == 0 && abs(xv(end) - 25.6) < 1e-12 && abs(h - 0.1) < 1e-12, ...
    '+x grid should be 257 positions from 0 to 25.6 m at 0.1 m');
[xv, h] = generateVehiclePositions(model, truck, 0.3, 1);
fprintf('  requested 0.3 m -> %d positions, actual step %.12g m (= 25.6/86)\n', numel(xv), h);
assert(numel(xv) == 87 && abs(h - 25.6/86) < 1e-12 && h <= 0.3, 'step should shrink to 25.6/86 m');
[xv, ~] = generateVehiclePositions(model, truck, 0.1, -1);
fprintf('  -x: from %g to %g m\n', xv(1), xv(end));
assert(xv(1) == 20 && abs(xv(end) + 5.6) < 1e-12, '-x grid should run from 20 to -5.6 m');
single = createVehicle(100e3, [], 'single axle');
[xv, ~] = generateVehiclePositions(model, single, 0.5, 1);
assert(xv(1) == 0 && xv(end) == 20 && numel(xv) == 41, 'single axle should run from 0 to 20 m');
fprintf('  PASS position grids (+x, -x, single axle)\n');

%% Only axles on the bridge act and an axle on a support goes into the reaction
model = createBeamModel(generateUniformMesh(L, 8), EI);
model = addSupport(model, 1, 'pin');
model = addSupport(model, 9, 'roller');
prep = prepareMovingLoad(model, generateUniformMesh(L, 8));
r0 = analyzeVehiclePosition(prep, truck, 0, 1);         % front axle on support A, others off
r2 = analyzeVehiclePosition(prep, truck, 2, 1);         % front axle at 2 m, others off
rEnd = analyzeVehiclePosition(prep, truck, 25.6, 1);    % rear axle on support B, others off
rAll = analyzeVehiclePosition(prep, truck, 15, 1);      % all axles on: 15, 10.8, 9.4 m
RAall = (80e3*(L - 15) + 120e3*(L - 10.8) + 120e3*(L - 9.4)) / L;
fprintf('  axles on bridge: xv=0 %s, xv=2 %s, xv=25.6 %s, xv=15 %s\n', mat2str(r0.axles.onBridge.'), ...
    mat2str(r2.axles.onBridge.'), mat2str(rEnd.axles.onBridge.'), mat2str(rAll.axles.onBridge.'));
assert(all(r0.U == 0) && all(rEnd.U == 0), 'axles on supports only must not bend the beam');
reportComparisons('On-bridge axle policy, spec truck on a 20 m simple span', [ ...
    compareToReference('xv = 0: R_A [kN] (front axle on support A)', r0.R(1)/1e3, 80, tol), ...
    compareToReference('xv = 0: R_B [kN]', r0.R(17)/1e3, 0, [], 1e-9), ...
    compareToReference('xv = 2: R_A [kN] (front axle only)', r2.R(1)/1e3, 80*(L - 2)/L, tol), ...
    compareToReference('xv = 25.6: R_B [kN] (rear axle on support B)', rEnd.R(17)/1e3, 120, tol), ...
    compareToReference('xv = 15: R_A [kN] (all axles on)', rAll.R(1)/1e3, RAall/1e3, tol), ...
    compareToReference('xv = 15: R_A + R_B [kN]', (rAll.R(1) + rAll.R(17))/1e3, 320, tol)]);

%% Invalid vehicle and moving-load input is rejected
assertThrows(@() createVehicle([80e3 -120e3], 4.2), 'BridgeFE:invalidVehicle');
assertThrows(@() createVehicle([80e3 120e3], [4.2 1.4]), 'BridgeFE:invalidVehicle');
assertThrows(@() createVehicle([80e3 120e3], 0), 'BridgeFE:invalidVehicle');
assertThrows(@() createVehicle([80e3 NaN], 4.2), 'BridgeFE:invalidVehicle');
assertThrows(@() vehicleAxlePositions(truck, 10, 2), 'BridgeFE:invalidInput');
model = createBeamModel(generateUniformMesh(L, 8), EI);
model = addSupport(model, 1, 'pin');
model = addSupport(model, 9, 'roller');
assertThrows(@() generateVehiclePositions(model, truck, 0, 1), 'BridgeFE:invalidInput');
assertThrows(@() runMovingLoad(model, truck, 'Stepp', 0.1), 'BridgeFE:invalidInput');
assertThrows(@() runMovingLoad(model, truck, 'Direction', 0), 'BridgeFE:invalidInput');
assertThrows(@() runMovingLoad(model, truck, 'Stations', [5 21]), 'BridgeFE:offBeam');

%TESTMOVINGLOADFASTPATH Factorize-once moving-load path vs the verified static engine.
%   Script-based test file (see runAllTests). analyzeVehiclePosition reuses
%   one Cholesky factor and its own vectorized evaluation. At many vehicle
%   positions it must reproduce the verified M1-M3 path: addPointLoad +
%   solveStaticModel + sampleInternalForces + evaluateDeflection. Both
%   limits of every jump are compared, at the stations and under the axles.
%   The model deliberately has unequal spans, two EI values, a uniform load
%   on one span, a nodal force and couple, and a permanent point load
%   inside an element.

%% Fast path equals the static engine at 14 positions in both directions
[x, xs] = meshSpans([12 15], [10 12]);
EI = [repmat(2e9, 10, 1); repmat(3e9, 12, 1)];
model = createBeamModel(x, EI);
model = addSupport(model, findNodeAtX(model, xs(1)), 'pin');
model = addSupport(model, findNodeAtX(model, xs(2)), 'roller');
model = addSupport(model, findNodeAtX(model, xs(3)), 'roller');
model = addUniformLoad(model, -10e3, elementsBetween(model, xs(1), xs(2)));
model = addNodalLoad(model, findNodeAtX(model, 6), -20e3, 5e3);
model = addPointLoad(model, 20.3, -30e3);
truck = createVehicle([80e3 120e3 120e3], [4.2 1.4], 'spec 3-axle example');
Le = diff(x);
stations = unique([x; x(1:end-1) + Le/4; x(1:end-1) + Le/2; x(1:end-1) + 3*Le/4]);
prep = prepareMovingLoad(model, stations);
cases = [0 1; 2.3 1; 6 1; 12 1; 13.7 1; 16.2 1; 20.25 1; 27 1; 30.9 1; 32.6 1; ...
         27 -1; 15.5 -1; 5.6 -1; -2.4 -1];     % [xv direction]; includes axles at nodes, at supports and off the bridge
worst = zeros(size(cases, 1), 6);
for k = 1:size(cases, 1)
    res = analyzeVehiclePosition(prep, truck, cases(k, 1), cases(k, 2));
    ref = model;
    on = res.axles.onBridge;
    xa = res.axles.x(on);
    Pa = res.axles.P(on);
    for j = 1:numel(xa)
        ref = addPointLoad(ref, xa(j), Pa(j));
    end
    rs = solveStaticModel(ref);
    smp = sampleInternalForces(ref, rs.U, 4);
    pts = [res.stations.x; res.axlePoints.x];
    VLf = [res.stations.VL; res.axlePoints.VL];
    VRf = [res.stations.VR; res.axlePoints.VR];
    Mf = [res.stations.ML; res.stations.MR; res.axlePoints.ML; res.axlePoints.MR];
    VLr = zeros(size(pts)); VRr = VLr; MLr = VLr; MRr = VLr;
    for p = 1:numel(pts)
        rows = find(abs(smp.x - pts(p)) < 1e-9);
        VLr(p) = smp.V(rows(1));  VRr(p) = smp.V(rows(end));
        MLr(p) = smp.M(rows(1));  MRr(p) = smp.M(rows(end));
    end
    vr = evaluateDeflection(ref, rs.U, pts);
    vf = [res.stations.v; res.axlePoints.v];
    worst(k, :) = [max(abs(res.U - rs.U)) / max(abs(rs.U)), ...
                   max(abs(res.R - rs.R)) / max(abs(rs.R)), ...
                   max(abs(VLf - VLr)) / max(abs(smp.V)), ...
                   max(abs(VRf - VRr)) / max(abs(smp.V)), ...
                   max(abs(Mf - [MLr(1:numel(stations)); MRr(1:numel(stations)); MLr(numel(stations)+1:end); MRr(numel(stations)+1:end)])) / max(abs(smp.M)), ...
                   max(abs(vf - vr)) / max(abs(vr))];
    fprintf('  xv = %6.2f dir %+d: %d axle(s) on bridge; max normalized diffs U %.1e R %.1e VL %.1e VR %.1e M %.1e v %.1e\n', ...
        cases(k, 1), cases(k, 2), nnz(on), worst(k, :));
end
reportComparisons('Fast moving-load path vs static engine (14 positions, 2-span model with permanent loads)', [ ...
    compareToReference('max|U_fast - U_ref| / max|U_ref| [-]', max(worst(:, 1)), 0, [], 1e-9), ...
    compareToReference('max|R_fast - R_ref| / max|R_ref| [-]', max(worst(:, 2)), 0, [], 1e-9), ...
    compareToReference('max|V(x-) diff| / max|V| [-]', max(worst(:, 3)), 0, [], 1e-9), ...
    compareToReference('max|V(x+) diff| / max|V| [-]', max(worst(:, 4)), 0, [], 1e-9), ...
    compareToReference('max|M diff| / max|M| [-] (both limits)', max(worst(:, 5)), 0, [], 1e-9), ...
    compareToReference('max|v diff| / max|v| [-]', max(worst(:, 6)), 0, [], 1e-9)]);

%% Single-element model with no axle on the bridge returns the permanent response
model = createBeamModel([0; 10], 2e9);
model = addSupport(model, 1, 'pin');
model = addSupport(model, 2, 'roller');
model = addUniformLoad(model, -20e3);
prep = prepareMovingLoad(model, [0; 2.5; 5; 10]);
res = analyzeVehiclePosition(prep, createVehicle(50e3, []), -3, 1);
ref = solveStaticModel(model);
assert(~any(res.axles.onBridge), 'the axle at -3 m must be off the bridge');
reportComparisons('No axle on a one-element simple span: permanent uniform load only', [ ...
    compareToReference('max|U - U_static| / max|U_static| [-]', max(abs(res.U - ref.U)) / max(abs(ref.U)), 0, [], 1e-12), ...
    compareToReference('M(5 m) [kN*m] = qL^2/8', res.stations.ML(3)/1e3, 250, 0.1), ...
    compareToReference('v(5 m) [mm] = -5qL^4/(384EI)', res.stations.v(3)*1e3, -5*20e3*1e4/(384*2e9)*1e3, 0.1)]);

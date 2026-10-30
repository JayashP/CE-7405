%TESTMATERIALS Steel (Es*Is) and RCC (Ec*Ieff) input through one solver.
%   Script-based test file (see runAllTests). PROJECT_SPEC.md section 4.4:
%   two otherwise identical steel and RCC models with EQUAL assigned EI must
%   give the same linear response. This checks input and solver consistency;
%   it is NOT a validation of concrete behaviour. No cracking model exists.
%   Values are chosen so the products are exact in binary:
%     steel  Es = 200 GPa, Is = 0.01 m^4      -> EI = 2e9 N*m^2
%     RCC    Ec = 32 GPa,  Ieff = 0.0625 m^4  -> EI = 2e9 N*m^2 (equal EI)
%     RCC    Ec = 32 GPa,  Ieff = 0.03125 m^4 -> EI = 1e9 N*m^2 (half)
%   Mixed spans L1 (EI1), L2 (EI2) under uniform q (three-moment equation
%   with flexural rigidities):
%     M_B = -q*(L1^3/EI1 + L2^3/EI2) / (8*(L1/EI1 + L2/EI2)),
%     R_A = q*L1/2 + M_B/L1,  R_C = q*L2/2 + M_B/L2,  R_B = q*(L1 + L2) - R_A - R_C
tol = 0.1;   % [%]

%% Steel and RCC records hold E, I and EI = E*I
steel = defineMaterial('steel', 200e9, 0.01);
rcc = defineMaterial('RCC', 32e9, 0.0625, 'RCC deck', 'Ieff assumed for this test, not computed');
fprintf('  steel: type %s, %s = %g m^4, E = %g GPa, EI = %g N*m^2, basis: %s\n', steel.type, steel.inertiaLabel, steel.I, steel.E/1e9, steel.EI, steel.basis);
fprintf('  rcc:   type %s, %s = %g m^4, E = %g GPa, EI = %g N*m^2, basis: %s\n', rcc.type, rcc.inertiaLabel, rcc.I, rcc.E/1e9, rcc.EI, rcc.basis);
assert(strcmp(steel.type, 'steel') && strcmp(steel.inertiaLabel, 'Is') && strcmp(steel.name, 'Steel'), 'steel record fields are wrong');
assert(strcmp(rcc.type, 'rcc') && strcmp(rcc.inertiaLabel, 'Ieff') && strcmp(rcc.name, 'RCC deck'), 'RCC record fields are wrong');
assert(steel.EI == 2e9 && rcc.EI == 2e9, 'EI must be E*I = 2e9 N*m^2 for both');
fprintf('  PASS EI = Es*Is = Ec*Ieff = 2e9 N*m^2 exactly\n');

%% Equal-EI steel and RCC models give identical static results
[x, xs] = meshSpans([10 15], [8 12]);
steel = defineMaterial('steel', 200e9, 0.01);
rcc = defineMaterial('rcc', 32e9, 0.0625);
results = cell(1, 3);
inputs = {steel, rcc, 2e9};
for k = 1:3
    model = createBeamModel(x, inputs{k});
    model = addSupport(model, findNodeAtX(model, xs(1)), 'pin');
    model = addSupport(model, findNodeAtX(model, xs(2)), 'roller');
    model = addSupport(model, findNodeAtX(model, xs(3)), 'roller');
    model = addUniformLoad(model, -20e3);
    model = addPointLoad(model, 16.3, -100e3);
    model = addNodalLoad(model, findNodeAtX(model, 5), 0, 15e3);
    results{k} = solveStaticModel(model);
end
rs = results{1};
rr = results{2};
rn = results{3};
same = isequal(rs.U, rr.U) && isequal(rs.R, rr.R) && isequal(rs.elementForces.endActions, rr.elementForces.endActions) ...
    && isequal(rs.U, rn.U) && isequal(rs.R, rn.R);
fprintf('  max|U_steel - U_rcc| = %g m, max|R_steel - R_rcc| = %g N, max|f_steel - f_rcc| = %g\n', ...
    max(abs(rs.U - rr.U)), max(abs(rs.R - rr.R)), max(abs(rs.elementForces.endActions(:) - rr.elementForces.endActions(:))));
assert(same, 'steel, RCC and numeric-EI models with equal EI must give bit-identical results');
fprintf('  PASS steel, RCC and plain-EI models (EI = 2e9) give bit-identical U, R and element forces\n');

%% Equal-EI steel and RCC models give identical moving-load envelopes
[x, xs] = meshSpans([12 15], [8 10]);
truck = createVehicle([80e3 120e3 120e3], [4.2 1.4], 'spec 3-axle example');
envs = cell(1, 2);
mats = {defineMaterial('steel', 200e9, 0.01), defineMaterial('rcc', 32e9, 0.0625)};
for k = 1:2
    model = createBeamModel(x, mats{k});
    model = addSupport(model, findNodeAtX(model, xs(1)), 'pin');
    model = addSupport(model, findNodeAtX(model, xs(2)), 'roller');
    model = addSupport(model, findNodeAtX(model, xs(3)), 'roller');
    envs{k} = runMovingLoad(model, truck, 'Step', 0.25);
end
assert(isequal(envs{1}.envelope, envs{2}.envelope) && isequal(envs{1}.reactions, envs{2}.reactions) ...
    && isequal([envs{1}.critical.value], [envs{2}.critical.value]), 'envelopes must be identical for equal EI');
fprintf('  PASS steel and RCC (equal EI) give identical envelopes, reactions and critical values (max M = %.4f kN*m)\n', ...
    envs{1}.critical(1).value/1e3);

%% A uniform change of EI scales deflections but not forces
[x, xs] = meshSpans([10 15], [8 12]);
out = cell(1, 2);
mats = {defineMaterial('steel', 200e9, 0.01), defineMaterial('rcc', 32e9, 0.03125)};   % EI 2e9 and 1e9
for k = 1:2
    model = createBeamModel(x, mats{k});
    model = addSupport(model, findNodeAtX(model, xs(1)), 'pin');
    model = addSupport(model, findNodeAtX(model, xs(2)), 'roller');
    model = addSupport(model, findNodeAtX(model, xs(3)), 'roller');
    model = addUniformLoad(model, -20e3);
    out{k} = solveStaticModel(model);
end
reportComparisons('Indeterminate two-span beam, EI 2e9 (steel) vs 1e9 (RCC) everywhere, q = 20 kN/m', [ ...
    compareToReference('max|U_rcc - 2*U_steel| / max|U_rcc| [-]', max(abs(out{2}.U - 2*out{1}.U)) / max(abs(out{2}.U)), 0, [], 1e-12), ...
    compareToReference('max|R_rcc - R_steel| / max|R| [-]', max(abs(out{2}.R - out{1}.R)) / max(abs(out{1}.R)), 0, [], 1e-12), ...
    compareToReference('max|M_rcc - M_steel| / max|M| [-]', max(abs(out{2}.elementForces.moment(:) - out{1}.elementForces.moment(:))) / max(abs(out{1}.elementForces.moment(:))), 0, [], 1e-12)]);

%% Steel and RCC spans redistribute the support moment as the three-moment equation predicts
L1 = 10;
L2 = 15;
q = 20e3;
steel = defineMaterial('steel', 200e9, 0.01);        % EI1 = 2e9
rcc = defineMaterial('rcc', 32e9, 0.03125);          % EI2 = 1e9
EI1 = steel.EI;
EI2 = rcc.EI;
MB = -q * (L1^3/EI1 + L2^3/EI2) / (8 * (L1/EI1 + L2/EI2));
RA = q*L1/2 + MB/L1;
RC = q*L2/2 + MB/L2;
RB = q*(L1 + L2) - RA - RC;
MBuniform = -q * (L1^3 + L2^3) / (8 * (L1 + L2));
[x, xs] = meshSpans([L1 L2], [8 12]);
model = createBeamModel(x, steel);
model = assignMaterial(model, rcc, elementsBetween(model, xs(2), xs(3)));
model = addSupport(model, findNodeAtX(model, xs(1)), 'pin');
B = findNodeAtX(model, xs(2));
C = findNodeAtX(model, xs(3));
model = addSupport(model, B, 'roller');
model = addSupport(model, C, 'roller');
model = addUniformLoad(model, -q);
res = solveStaticModel(model);
fprintf('  materials: %d (%s, %s); materialId span 1 = %s, span 2 = %s\n', numel(model.materials), ...
    model.materials(1).name, model.materials(2).name, mat2str(unique(model.elements.materialId(1:8)).'), ...
    mat2str(unique(model.elements.materialId(9:20)).'));
fprintf('  M_B with steel + RCC spans = %.4f kN*m; with uniform EI it would be %.4f kN*m\n', ...
    res.elementForces.moment(B, 1)/1e3, MBuniform/1e3);
assert(numel(model.materials) == 2 && all(model.elements.materialId(1:8) == 1) && all(model.elements.materialId(9:20) == 2), ...
    'span 1 must use material 1 (steel) and span 2 material 2 (RCC)');
reportComparisons(sprintf('Steel span %g m (EI %g) + RCC span %g m (EI %g), q = %g kN/m', L1, EI1, L2, EI2, q/1e3), [ ...
    compareToReference('M_B [kN*m] (three-moment, two EI)', res.elementForces.moment(B, 1)/1e3, MB/1e3, tol), ...
    compareToReference('M_B from span 1 [kN*m]', res.elementForces.moment(B - 1, 2)/1e3, MB/1e3, tol), ...
    compareToReference('R_A [kN]', res.R(1)/1e3, RA/1e3, tol), ...
    compareToReference('R_B [kN]', res.R(2*B - 1)/1e3, RB/1e3, tol), ...
    compareToReference('R_C [kN]', res.R(2*C - 1)/1e3, RC/1e3, tol), ...
    compareToReference('change of M_B vs uniform EI [kN*m]', (res.elementForces.moment(B, 1) - MBuniform)/1e3, (MB - MBuniform)/1e3, tol)]);

%% EI cannot be edited behind a material, but materials can be reassigned
steel = defineMaterial('steel', 200e9, 0.01);
rcc = defineMaterial('rcc', 32e9, 0.0625);
model = createBeamModel(generateUniformMesh(10, 4), steel);
broken = model;
broken.elements.EI(3) = 1.5e9;
assertThrows(@() assembleGlobalK(broken), 'BridgeFE:invalidModel');
model = assignMaterial(model, steel, [1 2]);
assert(numel(model.materials) == 1, 're-assigning an identical material must not duplicate it');
model = assignMaterial(model, rcc, 3);
assert(isequal(model.elements.materialId, [1; 1; 2; 1]) && model.elements.EI(3) == rcc.EI, 'element 3 must now be RCC');
fprintf('  PASS direct EI edit rejected; identical material reused; element 3 reassigned to RCC\n');

%% Unit slips trigger a warning but still create the material
lastwarn('');
m1 = defineMaterial('steel', 200, 0.01);              % GPa typed without the 1e9 factor
[msg1, id1] = lastwarn;
lastwarn('');
m2 = defineMaterial('rcc', 30e6, 0.05);               % MPa-level modulus
[msg2, id2] = lastwarn;
lastwarn('');
m3 = defineMaterial('rcc', 30e9, 0.05);               % plausible: no warning
[~, id3] = lastwarn;
fprintf('  steel E = 200 Pa -> %s: %s\n  rcc E = 30 MPa -> %s\n  rcc E = 30 GPa -> warning id ''%s''\n', id1, msg1, id2, id3);
assert(strcmp(id1, 'BridgeFE:unusualModulus') && strcmp(id2, 'BridgeFE:unusualModulus') && isempty(id3), ...
    'implausible moduli must warn and a plausible one must not');
assert(m1.EI == 2 && m2.EI == 30e6*0.05 && m3.EI == 30e9*0.05, 'materials must still be created');
fprintf('  PASS unit-sanity warnings\n');

%% Invalid material input is rejected
assertThrows(@() defineMaterial('timber', 12e9, 0.01), 'BridgeFE:invalidMaterial');
assertThrows(@() defineMaterial('steel', -200e9, 0.01), 'BridgeFE:invalidInput');
assertThrows(@() defineMaterial('rcc', 30e9, 0), 'BridgeFE:invalidInput');
bad = defineMaterial('steel', 200e9, 0.01);
bad.EI = 3e9;                                         % no longer E*I
assertThrows(@() createBeamModel([0; 5; 10], bad), 'BridgeFE:invalidMaterial');
model = createBeamModel([0; 5; 10], defineMaterial('steel', 200e9, 0.01));
assertThrows(@() assignMaterial(model, defineMaterial('rcc', 30e9, 0.05), 3), 'BridgeFE:invalidInput');

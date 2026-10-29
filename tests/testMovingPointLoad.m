%TESTMOVINGPOINTLOAD Benchmark B: single point load at many positions on a simple span.
%   Script-based test file (see runAllTests). PROJECT_SPEC.md section 10,
%   Benchmark B. A downward load P at distance a from the left support of
%   a simply supported span L (b = L - a). Analytical references (fixed;
%   never edit them to make a test pass):
%     R_A = P*(L - a)/L,  R_B = P*a/L,  M(a) = P*a*(L - a)/L (under the load),
%     v(a) = -P*a^2*b^2/(3*EI*L),  shear jump of size P under the load,
%     maximum of M(a) over positions at a = L/2: M = P*L/4.
%   The mesh is deliberately coarse (8 elements of 2.5 m), so most
%   positions are inside elements; positions at nodes, at the supports and
%   just either side of a node are included. Acceptance: < 0.5 % (spec)
%   for nonzero references; zero references (load at a support) use an
%   absolute tolerance of 1e-6 times the characteristic value.
L = 20;            % [m]
P = 100e3;         % load magnitude [N], acts downward
EI = 200e9 * 0.01; % [N*m^2]
ne = 8;            % Le = 2.5 m
tolB = 0.5;
positions = unique([linspace(0, L, 81), 0.1, 1.234, 7.77, 12.3456, 19.99, 5 - 1e-7, 5 + 1e-7]);

%% Benchmark B over 88 load positions with an 8-element mesh
base = createBeamModel(generateUniformMesh(L, ne), EI);
base = addSupport(base, 1, 'pin');
base = addSupport(base, ne + 1, 'roller');
B = ne + 1;
np = numel(positions);
RA = zeros(np, 1); RB = RA; Munder = RA; Mmax = RA; Vjump = RA; vUnder = RA; sumFv = RA; sumM = RA;
for k = 1:np
    a = positions(k);
    model = addPointLoad(base, a, -P);
    res = solveStaticModel(model);
    s = sampleInternalForces(model, res.U, 4);
    at = abs(s.x - a) <= 1e-9 * L;
    RA(k) = res.R(1);
    RB(k) = res.R(2*B - 1);
    Munder(k) = max(s.M(at));
    Mmax(k) = max(s.M);
    Vjump(k) = max(s.V(at)) - min(s.V(at));
    vUnder(k) = evaluateDeflection(model, res.U, a);
    sumFv(k) = res.diagnostics.sumVerticalForce;
    sumM(k) = res.diagnostics.sumMomentAboutOrigin;
end
a = positions(:);
b = L - a;
RAref = P * b / L;
RBref = P * a / L;
Mref = P * a .* b / L;
vRef = -P * a.^2 .* b.^2 / (3*EI*L);
inner = a > 0 & a < L;                      % load not on a support
pct = @(act, ref) 100 * max(abs(act(inner) - ref(inner)) ./ abs(ref(inner)));
show = find(ismember(round(a * 1e7), round([0 0.1 1.234 2.5 4.75 5 7.77 10 12.3456 15.25 19.99 20] * 1e7)));
fprintf('  %9s %12s %12s %13s %13s %13s %13s\n', 'a [m]', 'R_A [kN]', 'R_A exact', 'M(a) [kN*m]', 'M(a) exact', 'v(a) [mm]', 'v(a) exact');
for k = show.'
    fprintf('  %9.4f %12.6f %12.6f %13.6f %13.6f %13.7f %13.7f\n', a(k), RA(k)/1e3, RAref(k)/1e3, ...
        Munder(k)/1e3, Mref(k)/1e3, vUnder(k)*1e3, vRef(k)*1e3);
end
[Mcrit, kc] = max(Munder);
reportComparisons(sprintf('Benchmark B: L = %g m, P = %g kN, %d elements, %d positions (%d inside elements)', ...
    L, P/1e3, ne, np, nnz(abs(a/2.5 - round(a/2.5)) > 1e-9)), [ ...
    compareToReference('max rel. error of R_A over positions [%]', pct(RA, RAref), 0, [], tolB), ...
    compareToReference('max rel. error of R_B over positions [%]', pct(RB, RBref), 0, [], tolB), ...
    compareToReference('max rel. error of M under load [%]', pct(Munder, Mref), 0, [], tolB), ...
    compareToReference('max rel. error of v under load [%]', pct(vUnder, vRef), 0, [], tolB), ...
    compareToReference('max rel. error of shear jump vs P [%]', 100 * max(abs(Vjump(inner) - P)) / P, 0, [], tolB), ...
    compareToReference('max|M_max(samples) - M(a)| / (PL/4) [-]', max(abs(Mmax(inner) - Munder(inner))) / (P*L/4), 0, [], 1e-9), ...
    compareToReference('load at a = 0: R_A [kN]', RA(1)/1e3, P/1e3, tolB), ...
    compareToReference('load at a = 0: R_B [kN]', RB(1)/1e3, 0, [], 1e-6 * P/1e3), ...
    compareToReference('load at a = L: R_B [kN]', RB(end)/1e3, P/1e3, tolB), ...
    compareToReference('critical position a* for max M [m]', a(kc), L/2, tolB), ...
    compareToReference('max M over positions [kN*m]', Mcrit/1e3, P*L/4/1e3, tolB), ...
    compareToReference('max|sum Fv| over positions [kN]', max(abs(sumFv))/1e3, 0, [], 1e-6 * P/1e3), ...
    compareToReference('max|sum M about 0| over positions [kN*m]', max(abs(sumM))/1e3, 0, [], 1e-6 * P*L/1e3)]);

%% Results are continuous as the load crosses a node
base = createBeamModel(generateUniformMesh(L, ne), EI);
base = addSupport(base, 1, 'pin');
base = addSupport(base, ne + 1, 'roller');
delta = 1e-7;
r0 = solveStaticModel(addPointLoad(base, 5, -P));
rL = solveStaticModel(addPointLoad(base, 5 - delta, -P));
rR = solveStaticModel(addPointLoad(base, 5 + delta, -P));
assert(r0.pointLoads.node == 3 && rL.pointLoads.element == 2 && rR.pointLoads.element == 3, ...
    'loads at 5, 5 - 1e-7 and 5 + 1e-7 m should sit on node 3, in element 2 and in element 3');
Uscale = max(abs(r0.U));
reportComparisons('Load at x = 5 m (node 3) vs 1e-7 m to either side (elements 2 and 3)', [ ...
    compareToReference('max|U(5 - d) - U(5)| / max|U| [-]', max(abs(rL.U - r0.U)) / Uscale, 0, [], 1e-6), ...
    compareToReference('max|U(5 + d) - U(5)| / max|U| [-]', max(abs(rR.U - r0.U)) / Uscale, 0, [], 1e-6), ...
    compareToReference('|R_A(5 + d) - R_A(5 - d)| [N] (exact 2*P*d/L)', abs(rR.R(1) - rL.R(1)), 2*P*delta/L, 1)]);

%TESTBEAMSTIFFNESS Unit tests for beamElementStiffness (script-based test file).
%   Each '%%' section is an independent test and this header is the shared
%   setup. Run all tests with runAllTests (MATLAB or GNU Octave).
%   Expected matrices are hand-computed literals, or are written out from
%   the four coefficients 12EI/L^3, 6EI/L^2, 4EI/L and 2EI/L independently
%   of the factored form in the source. Never edit them to make a test pass.
roundoffPct = 1e-10;   % algebraic identities: round-off only (1e-12 relative)

%% Exact matrix for EI = 2e9 N*m^2 and Le = 2 m (hand-computed literals)
% EI/Le^3 = 2.5e8 N/m, so 12EI/Le^3 = 3e9, 6EI/Le^2 = 3e9, 4EI/Le = 4e9, 2EI/Le = 2e9.
ke = beamElementStiffness(2e9, 2);
expected = 1e9 * [  3   3  -3   3
                    3   4  -3   2
                   -3  -3   3  -3
                    3   2  -3   4 ];
fprintf('  ke(EI = 2e9 N*m^2, Le = 2 m), DOFs [v1 theta1 v2 theta2]:\n');
disp(ke);
assert(isequal(size(ke), [4 4]), 'ke must be 4-by-4');
maxRelEntryError = max(abs(ke(:) - expected(:))) / max(abs(expected(:)));
reportComparisons('Element stiffness, EI = 2e9 N*m^2, Le = 2 m', [ ...
    compareToReference('k11 = 12EI/Le^3 [N/m]', ke(1,1), 3e9, roundoffPct), ...
    compareToReference('k12 = 6EI/Le^2 [N/rad]', ke(1,2), 3e9, roundoffPct), ...
    compareToReference('k13 = -12EI/Le^3 [N/m]', ke(1,3), -3e9, roundoffPct), ...
    compareToReference('k22 = 4EI/Le [N*m/rad]', ke(2,2), 4e9, roundoffPct), ...
    compareToReference('k24 = 2EI/Le [N*m/rad]', ke(2,4), 2e9, roundoffPct), ...
    compareToReference('k34 = -6EI/Le^2 [N/rad]', ke(3,4), -3e9, roundoffPct), ...
    compareToReference('max|ke - expected| / max|expected| [-]', maxRelEntryError, 0, [], 1e-14)]);

%% Unit EI and unit length give the integer coefficient matrix exactly
ke = beamElementStiffness(1, 1);
expected = [ 12   6  -12   6
              6   4   -6   2
            -12  -6   12  -6
              6   2   -6   4 ];
disp(ke);
assert(isequal(ke, expected), 'beamElementStiffness(1, 1) must equal the integer coefficient matrix exactly');
fprintf('  PASS beamElementStiffness(1, 1) equals the integer coefficient matrix exactly\n');

%% Spec mesh example Le = 1.5 m with steel E = 200 GPa and I = 0.01 m^4
EI = 200e9 * 0.01;
Le = 30 / 20;
a = 12 * EI / Le^3;
b = 6 * EI / Le^2;
c = 4 * EI / Le;
d = 2 * EI / Le;
expected = [  a   b  -a   b
              b   c  -b   d
             -a  -b   a  -b
              b   d  -b   c ];
ke = beamElementStiffness(EI, Le);
disp(ke);
maxRelEntryError = max(abs(ke(:) - expected(:))) / max(abs(expected(:)));
reportComparisons('Element stiffness, EI = 2e9 N*m^2, Le = 1.5 m', [ ...
    compareToReference('k11 = 12EI/Le^3 [N/m]', ke(1,1), a, roundoffPct), ...
    compareToReference('k22 = 4EI/Le [N*m/rad]', ke(2,2), c, roundoffPct), ...
    compareToReference('k24 = 2EI/Le [N*m/rad]', ke(2,4), d, roundoffPct), ...
    compareToReference('max|ke - expected| / max|expected| [-]', maxRelEntryError, 0, [], 1e-14)]);

%% Element matrix is exactly symmetric for arbitrary EI and Le
cases = [2e9 1.5; 3.7e8 0.37; 1 1; 5.123e10 12.75; 1e-3 1e3];
for k = 1:size(cases, 1)
    ke = beamElementStiffness(cases(k, 1), cases(k, 2));
    fprintf('  EI = %-10g Le = %-8g max|ke - ke''| = %g\n', cases(k, 1), cases(k, 2), max(max(abs(ke - ke.'))));
    assert(isequal(ke, ke.'), 'ke is not exactly symmetric for EI = %g, Le = %g', cases(k, 1), cases(k, 2));
end

%% Rigid-body modes lie in the null space and ke is positive semi-definite of rank 2
EI = 2e9;
Le = 1.5;
ke = beamElementStiffness(EI, Le);
translation = [1; 0; 1; 0];       % v = 1, theta = 0
rotation = [0; 1; Le; 1];         % rigid rotation about node 1: v = x, theta = 1
scale = max(abs(ke(:)));
lambda = sort(eig(ke));
fprintf('  eigenvalues of ke: %s\n', mat2str(lambda.', 6));
assert(lambda(3) > 0 && lambda(4) > 0, 'ke must have two positive eigenvalues');
reportComparisons('Element rigid-body modes and definiteness, EI = 2e9 N*m^2, Le = 1.5 m', [ ...
    compareToReference('max|ke*translation| / max|ke| [-]', max(abs(ke * translation)) / scale, 0, [], 1e-12), ...
    compareToReference('max|ke*rotation| / max|ke| [-]', max(abs(ke * rotation)) / scale, 0, [], 1e-12), ...
    compareToReference('rank(ke) [-]', rank(ke), 2, roundoffPct), ...
    compareToReference('min eigenvalue / max eigenvalue [-]', lambda(1) / lambda(4), 0, [], 1e-12)]);

%% Stiffness scales linearly with EI, as later EI-reduction studies assume
EI = 2e9;
Le = 1.5;
ratio = 0.7;
ke = beamElementStiffness(EI, Le);
keScaled = beamElementStiffness(ratio * EI, Le);
relErr = max(abs(keScaled(:) - ratio * ke(:))) / max(abs(ke(:)));
reportComparisons('Linearity in EI', ...
    compareToReference('max|k(0.7EI) - 0.7k(EI)| / max|k(EI)| [-]', relErr, 0, [], 1e-14));

%% Invalid EI or Le inputs are rejected with BridgeFE:invalidInput
badValues = {0, -2e9, NaN, Inf, [1 2], 1 + 2i, 'abc', true, []};
for k = 1:numel(badValues)
    bad = badValues{k};
    assertThrows(@() beamElementStiffness(bad, 1.5), 'BridgeFE:invalidInput');
    assertThrows(@() beamElementStiffness(2e9, bad), 'BridgeFE:invalidInput');
end

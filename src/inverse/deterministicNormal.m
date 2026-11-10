function z = deterministicNormal(n, seed)
%DETERMINISTICNORMAL Reproducible standard-normal numbers, identical in MATLAB and GNU Octave.
%   Z = DETERMINISTICNORMAL(N, SEED) returns an N-by-1 vector of
%   pseudo-random standard-normal numbers for the integer SEED >= 0.
%   MATLAB's rng and Octave's randn give different streams for the same
%   seed; this generator does not, so synthetic noisy test cases are the
%   same on both platforms. Uniform numbers come from the 32-bit linear
%   congruential generator u(k+1) = (1664525 u(k) + 1013904223) mod 2^32
%   (all products stay below 2^53, so double arithmetic is exact), turned
%   into normal numbers by the Box-Muller transform. Adequate for test
%   noise; not for statistics or cryptography.
%
%   See also ADDMEASUREMENTNOISE.

if ~(isnumeric(n) && isscalar(n) && n >= 0 && n == round(n))
    error('BridgeFE:invalidInput', 'N must be a non-negative integer.');
end
if ~(isnumeric(seed) && isscalar(seed) && seed >= 0 && seed == round(seed))
    error('BridgeFE:invalidInput', 'SEED must be a non-negative integer.');
end
m = 2^32;
state = mod(double(seed), m);
nPairs = ceil(n / 2);
uni = zeros(2 * nPairs, 1);
for k = 1:2 * nPairs
    state = mod(1664525 * state + 1013904223, m);
    uni(k) = (state + 0.5) / m;                 % in (0, 1), never 0 or 1
end
u1 = uni(1:2:end);
u2 = uni(2:2:end);
r = sqrt(-2 * log(u1));
z = reshape([r .* cos(2*pi*u2), r .* sin(2*pi*u2)].', [], 1);
z = z(1:n);
end

function h = hashSeed32(x)
%HASHSEED32 Integer hash of a 32-bit value, computed exactly with doubles (MATLAB and GNU Octave).
%   H = HASHSEED32(X) returns the "lowbias32" integer hash (C. Wellons,
%   hash-prospector) of the integer 0 <= X < 2^32:
%       x ^= x >> 16;  x *= 0x7feb352d;  x ^= x >> 15;  x *= 0x846ca68b;  x ^= x >> 16
%   with multiplication modulo 2^32. Products are split into 16-bit halves
%   so every intermediate stays below 2^53 and double arithmetic is exact
%   on both platforms. DETERMINISTICNORMAL uses it to turn consecutive seeds
%   (1, 2, 3, ...) into unrelated generator states; without it the first
%   numbers of neighbouring seeds are almost equal (DECISIONS.md D-029).
%
%   See also DETERMINISTICNORMAL.

if ~(isnumeric(x) && isscalar(x) && x >= 0 && x < 2^32 && x == round(x))
    error('BridgeFE:invalidInput', 'X must be an integer with 0 <= X < 2^32.');
end
h = double(x);
h = bitxor(h, floor(h / 2^16));
h = mulmod32(h, 2146121005);              % 0x7feb352d
h = bitxor(h, floor(h / 2^15));
h = mulmod32(h, 2221713035);              % 0x846ca68b
h = bitxor(h, floor(h / 2^16));
end

function r = mulmod32(x, a)
% (x * a) mod 2^32 for 0 <= x, a < 2^32, exact in double precision.
xh = floor(x / 2^16);
xl = x - xh * 2^16;
r = mod(mod(xh * a, 2^16) * 2^16 + xl * a, 2^32);
end

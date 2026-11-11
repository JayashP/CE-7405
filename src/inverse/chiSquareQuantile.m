function x = chiSquareQuantile(p, k)
%CHISQUAREQUANTILE Quantile of the chi-square distribution (no toolbox needed).
%   X = CHISQUAREQUANTILE(P, K) returns x with P(chi2_K <= x) = P, for
%   0 < P < 1 and K >= 1 degrees of freedom, e.g. chiSquareQuantile(0.95, 2)
%   = 5.9915. The chi-square CDF is the regularized lower incomplete gamma
%   function, F(x) = gammainc(x/2, K/2) (core MATLAB and GNU Octave, no
%   Statistics Toolbox), and x is found by bisection to a relative width
%   of 1e-13. Used by IDENTIFYSINGLEDAMAGE for the likelihood-ratio region
%   and the goodness-of-fit check.
%
%   See also IDENTIFYSINGLEDAMAGE.

if ~(isnumeric(p) && isscalar(p) && p > 0 && p < 1)
    error('BridgeFE:invalidInput', 'Probability P must satisfy 0 < P < 1.');
end
if ~(isnumeric(k) && isscalar(k) && isfinite(k) && k >= 1)
    error('BridgeFE:invalidInput', 'Degrees of freedom K must be a number >= 1.');
end
cdf = @(x) gammainc(x / 2, k / 2);
lo = 0;
hi = max(1, k);
while cdf(hi) < p
    lo = hi;
    hi = 2 * hi;
end
for iter = 1:300
    mid = (lo + hi) / 2;
    if cdf(mid) < p
        lo = mid;
    else
        hi = mid;
    end
    if hi - lo <= 1e-13 * hi
        break
    end
end
x = (lo + hi) / 2;
end

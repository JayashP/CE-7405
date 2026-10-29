function row = compareToReference(quantity, actual, expected, relTolPct, absTol)
%COMPARETOREFERENCE Compare a computed value with a fixed analytical reference.
%   ROW = COMPARETOREFERENCE(QUANTITY, ACTUAL, EXPECTED, RELTOLPCT, ABSTOL)
%   returns a struct with fields quantity, actual, expected, absError,
%   relErrorPct, criterion and pass:
%     EXPECTED ~= 0  pass if 100*|ACTUAL - EXPECTED|/|EXPECTED| <= RELTOLPCT
%     EXPECTED == 0  a percentage is undefined, so pass if
%                    |ACTUAL - EXPECTED| <= ABSTOL (ABSTOL required)
%   ACTUAL, EXPECTED and ABSTOL must be in the same units. A NaN or Inf
%   ACTUAL fails. Print rows with REPORTCOMPARISONS.

if nargin < 5
    absTol = [];
end
actual = full(double(actual));
expected = full(double(expected));
if ~(isscalar(actual) && isscalar(expected))
    error('BridgeFE:test:notScalar', 'Comparison "%s" needs scalar actual and expected values.', quantity);
end

absError = abs(actual - expected);
if expected ~= 0
    relErrorPct = 100 * absError / abs(expected);
    criterion = sprintf('rel<=%g%%', relTolPct);
    pass = relErrorPct <= relTolPct;
else
    if isempty(absTol)
        error('BridgeFE:test:missingAbsTol', ...
            'Reference for "%s" is zero; an absolute tolerance is required.', quantity);
    end
    relErrorPct = NaN;
    criterion = sprintf('abs<=%g', absTol);
    pass = absError <= absTol;
end
pass = logical(pass) && isfinite(actual);

row = struct('quantity', quantity, 'actual', actual, 'expected', expected, ...
    'absError', absError, 'relErrorPct', relErrorPct, 'criterion', criterion, 'pass', pass);
end

function [x, xSupports] = meshSpans(spanLengths, elementsPerSpan)
%MESHSPANS Node coordinates for a multi-span beam with a node at every support.
%   [X, XSUPPORTS] = MESHSPANS(SPANLENGTHS, ELEMENTSPERSPAN) divides each
%   span k of length SPANLENGTHS(k) [m] into ELEMENTSPERSPAN(k) equal
%   elements (a scalar applies to every span). X is the column vector of
%   node coordinates [m] from x = 0, and XSUPPORTS = [0; cumsum(SPANLENGTHS)]
%   holds the span-end (support) coordinates, each of which is exactly a
%   node of X. Supports are then placed with
%   ADDSUPPORT(MODEL, FINDNODEATX(MODEL, XSUPPORTS(k)), TYPE).
%
%   Example (two 10 m spans, 16 elements each):
%     [x, xs] = meshSpans([10 10], 16);
%     model = createBeamModel(x, 2e9);
%
%   See also GENERATEUNIFORMMESH, CREATEBEAMMODEL, FINDNODEATX.

if ~(isnumeric(spanLengths) && isreal(spanLengths) && isvector(spanLengths) ...
        && all(isfinite(spanLengths)) && all(spanLengths > 0))
    error('BridgeFE:invalidInput', 'spanLengths must be a vector of real, finite, positive lengths [m].');
end
spanLengths = double(spanLengths(:));
nSpans = numel(spanLengths);
if isscalar(elementsPerSpan)
    elementsPerSpan = repmat(elementsPerSpan, nSpans, 1);
end
if ~(isnumeric(elementsPerSpan) && isreal(elementsPerSpan) && numel(elementsPerSpan) == nSpans ...
        && all(isfinite(elementsPerSpan)) && all(elementsPerSpan == round(elementsPerSpan)) ...
        && all(elementsPerSpan >= 1))
    error('BridgeFE:invalidInput', ...
        'elementsPerSpan must be a positive integer or one positive integer per span (%d).', nSpans);
end

xSupports = [0; cumsum(spanLengths)];
x = 0;
for k = 1:nSpans
    n = elementsPerSpan(k);
    xk = xSupports(k) + spanLengths(k) * ((1:n)' / n);
    xk(end) = xSupports(k+1);        % span end coincides exactly with the support
    x = [x; xk]; %#ok<AGROW>
end
end

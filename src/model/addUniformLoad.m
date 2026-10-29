function model = addUniformLoad(model, w, elements)
%ADDUNIFORMLOAD Add a uniformly distributed load over whole elements.
%   MODEL = ADDUNIFORMLOAD(MODEL, W) adds a uniform load of intensity W [N/m]
%   to every element. W is positive UPWARD (DECISIONS.md D-003): a downward
%   dead load or lane load of magnitude q is entered as W = -q.
%   MODEL = ADDUNIFORMLOAD(MODEL, W, ELEMENTS) loads only the listed element
%   indices, for example a single span selected with ELEMENTSBETWEEN.
%   Loads added to the same element are superposed.
%
%   Example (20 kN/m downward on the first span of a two-span beam):
%     model = addUniformLoad(model, -20e3, elementsBetween(model, 0, 10));
%
%   See also ELEMENTSBETWEEN, EQUIVALENTDISTRIBUTEDLOAD, ADDNODALLOAD.

validateModel(model);
ne = size(model.elements.conn, 1);
assertFiniteRealScalar(w, 'w');
if nargin < 3
    elements = (1:ne)';
end
if ~(isnumeric(elements) && isreal(elements) && isvector(elements) && all(isfinite(elements)) ...
        && all(elements == round(elements)) && all(elements >= 1) && all(elements <= ne))
    error('BridgeFE:invalidInput', 'elements must be a vector of element indices between 1 and %d.', ne);
end
elements = unique(elements(:));

model.loads.elementUDL(elements) = model.loads.elementUDL(elements) + double(w);
end

function model = applyStiffnessDamage(model, elements, d)
%APPLYSTIFFNESSDAMAGE Prescribe an effective flexural-stiffness loss in selected elements (Stage 2).
%   MODEL = APPLYSTIFFNESSDAMAGE(MODEL, ELEMENTS, D) sets the stiffness
%   factor of the listed ELEMENTS to 1 - D, so that their analysed rigidity
%   becomes
%       EI_D = (1 - D) * EI_healthy,     0 <= D < 1     (PROJECT_SPEC.md section 6)
%   D is a scalar (same loss for all listed elements) or one value per
%   element. The loss REPLACES any earlier loss of those elements, and
%   D = 0 restores them. EI_healthy (the material E*I) is not changed;
%   EFFECTIVEEI gives the value the solver uses.
%
%   D is a reduction of MODEL flexural rigidity. It is not a percentage of
%   corrosion, section loss or load-carrying capacity (spec sections 4.4 and 14).
%
%   Example (30 % EI loss in the elements of 8-10 m):
%     model = applyStiffnessDamage(model, elementsBetween(model, 8, 10), 0.30);
%
%   See also EFFECTIVEEI, COMPAREHEALTHYDAMAGED, DAMAGESENSITIVITY.

validateModel(model);
ne = size(model.elements.conn, 1);
if ~(isnumeric(elements) && isreal(elements) && isvector(elements) && all(isfinite(elements)) ...
        && all(elements == round(elements)) && all(elements >= 1) && all(elements <= ne))
    error('BridgeFE:invalidInput', 'elements must be a vector of element indices between 1 and %d.', ne);
end
elements = elements(:);
if ~(isnumeric(d) && isreal(d) && all(isfinite(d(:))) && (isscalar(d) || numel(d) == numel(elements)))
    error('BridgeFE:invalidInput', 'd must be a real scalar or one value per listed element.');
end
if any(d(:) < 0 | d(:) >= 1)
    error('BridgeFE:invalidInput', 'Stiffness loss d must satisfy 0 <= d < 1 (got %s).', mat2str(d(:).', 4));
end
model.elements.stiffnessFactor(elements) = 1 - d(:);
end

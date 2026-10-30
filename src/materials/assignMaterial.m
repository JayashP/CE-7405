function model = assignMaterial(model, material, elements)
%ASSIGNMATERIAL Give elements the flexural rigidity of a steel or RCC material.
%   MODEL = ASSIGNMATERIAL(MODEL, MATERIAL) sets EI = MATERIAL.EI for every
%   element and records the material (DECISIONS.md D-022).
%   MODEL = ASSIGNMATERIAL(MODEL, MATERIAL, ELEMENTS) does so only for the
%   listed element indices. Different spans can therefore carry different
%   materials, for example a steel span and an RCC span selected with
%   ELEMENTSBETWEEN.
%   The material is added to model.materials once (identical records are
%   reused) and model.elements.materialId points to it. Afterwards the EI
%   of those elements must stay equal to the material's E*I (VALIDATEMODEL
%   checks it). Change it by assigning another material, not by editing EI.
%
%   Example (steel span 1, RCC span 2):
%     model = assignMaterial(model, defineMaterial('steel', 200e9, 0.01), elementsBetween(model, 0, 10));
%     model = assignMaterial(model, defineMaterial('rcc', 32e9, 0.0625), elementsBetween(model, 10, 25));
%
%   See also DEFINEMATERIAL, CREATEBEAMMODEL, ELEMENTSBETWEEN.

validateModel(model);
validateMaterial(material);
ne = size(model.elements.conn, 1);
if nargin < 3
    elements = (1:ne)';
end
if ~(isnumeric(elements) && isreal(elements) && isvector(elements) && all(isfinite(elements)) ...
        && all(elements == round(elements)) && all(elements >= 1) && all(elements <= ne))
    error('BridgeFE:invalidInput', 'elements must be a vector of element indices between 1 and %d.', ne);
end
elements = unique(elements(:));

id = 0;
for k = 1:numel(model.materials)
    if isequal(model.materials(k), material)
        id = k;
        break
    end
end
if id == 0
    model.materials(end+1) = material;
    id = numel(model.materials);
end
model.elements.materialId(elements) = id;
model.elements.EI(elements) = material.EI;
end

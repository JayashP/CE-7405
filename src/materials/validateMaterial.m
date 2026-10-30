function validateMaterial(material)
%VALIDATEMATERIAL Check a material record created by DEFINEMATERIAL.
%   VALIDATEMATERIAL(MATERIAL) returns silently for a valid scalar material
%   record and otherwise throws 'BridgeFE:invalidMaterial'. It checks that
%   the fields exist, the type is 'steel' or 'rcc', E and I are real, finite
%   and positive, and EI equals E*I to round-off (so EI cannot drift from
%   its stated basis).
%
%   See also DEFINEMATERIAL, ASSIGNMATERIAL.

id = 'BridgeFE:invalidMaterial';
fields = {'type', 'name', 'E', 'I', 'EI', 'inertiaLabel', 'basis'};
if ~(isstruct(material) && isscalar(material) && all(isfield(material, fields)))
    error(id, 'material must be a scalar struct created by defineMaterial.');
end
if ~(ischar(material.type) && any(strcmp(material.type, {'steel', 'rcc'})))
    error(id, 'material.type must be ''steel'' or ''rcc''.');
end
values = [material.E, material.I, material.EI];
if ~(isnumeric(values) && isreal(values) && all(isfinite(values)) && all(values > 0))
    error(id, 'material E, I and EI must be real, finite and positive.');
end
if abs(material.EI - material.E * material.I) > 1e-12 * material.EI
    error(id, 'material.EI (%g) is not E*I (%g); create materials with defineMaterial.', ...
        material.EI, material.E * material.I);
end
end

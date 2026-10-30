function material = defineMaterial(type, E, I, name, basis)
%DEFINEMATERIAL Steel or RCC flexural-rigidity input for the equivalent beam.
%   MATERIAL = DEFINEMATERIAL(TYPE, E, I) returns a material record whose
%   flexural rigidity EI = E*I is what the solver uses (DECISIONS.md D-022).
%   There is ONE solver; the material only documents where EI came from:
%     'steel'  E = Es [Pa], I = Is [m^4] of the steel section: EI = Es*Is.
%     'rcc'    E = Ec [Pa], I = Ieff [m^4]: EI = Ec*Ieff. Ieff is supplied by
%              the user or justified elsewhere for the assumed cracking state
%              and held CONSTANT in the linear analysis. This tool does not
%              compute Ieff and does not model cracking, reinforcement
%              yielding, creep, shrinkage or any other nonlinear concrete
%              behaviour (PROJECT_SPEC.md section 4.4).
%   MATERIAL = DEFINEMATERIAL(TYPE, E, I, NAME, BASIS) also sets a display
%   NAME and a BASIS note recording where E and I come from (traceability).
%
%   Unit-sanity check: a warning 'BridgeFE:unusualModulus' is issued when E
%   is outside 150-250 GPa (steel) or 10-70 GPa (rcc). This usually means a
%   unit slip (e.g. 200 entered instead of 200e9 Pa). The ranges are broad
%   plausibility bounds, not engineering limits, and the material is still
%   created.
%
%   MATERIAL fields: type ('steel' | 'rcc'), name, E [Pa], I [m^4],
%   EI [N*m^2], inertiaLabel ('Is' | 'Ieff'), basis.
%
%   Example (steel E = 200 GPa, Is = 0.01 m^4; RCC Ec = 32 GPa, Ieff = 0.0625 m^4):
%     steel = defineMaterial('steel', 200e9, 0.01);
%     rcc = defineMaterial('rcc', 32e9, 0.0625, 'RCC span', 'Ieff from external cracked-section check');
%
%   See also ASSIGNMATERIAL, CREATEBEAMMODEL, VALIDATEMATERIAL.

if isa(type, 'string') && isscalar(type)
    type = char(type);
end
if ~(ischar(type) && isrow(type) && any(strcmpi(type, {'steel', 'rcc'})))
    error('BridgeFE:invalidMaterial', 'Material type must be ''steel'' or ''rcc''.');
end
type = lower(type);
assertPositiveFiniteScalar(E, 'E');
assertPositiveFiniteScalar(I, 'I');

if strcmp(type, 'steel')
    defaultName = 'Steel';
    inertiaLabel = 'Is';
    defaultBasis = 'EI = Es*Is (steel section)';
    range = [150e9, 250e9];
else
    defaultName = 'RCC';
    inertiaLabel = 'Ieff';
    defaultBasis = 'EI = Ec*Ieff, Ieff user-supplied and constant (no cracking analysis in this tool)';
    range = [10e9, 70e9];
end
if nargin < 4 || isempty(name)
    name = defaultName;
end
if nargin < 5 || isempty(basis)
    basis = defaultBasis;
end
if isa(name, 'string') && isscalar(name)
    name = char(name);
end
if isa(basis, 'string') && isscalar(basis)
    basis = char(basis);
end
if ~(ischar(name) && isrow(name)) || ~(ischar(basis) && isrow(basis))
    error('BridgeFE:invalidMaterial', 'name and basis must be character vectors.');
end
if E < range(1) || E > range(2)
    warning('BridgeFE:unusualModulus', ...
        ['%s modulus E = %g Pa is outside the usual %g-%g GPa. Check the units ' ...
         '(the engine expects Pa); the material was still created.'], ...
        defaultName, E, range(1)/1e9, range(2)/1e9);
end

material = struct('type', type, 'name', name, 'E', double(E), 'I', double(I), ...
    'EI', double(E) * double(I), 'inertiaLabel', inertiaLabel, 'basis', basis);
end

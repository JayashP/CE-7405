function [model, info] = buildModelFromInputs(in)
%BUILDMODELFROMINPUTS Beam model from the app's model inputs (display units).
%   [MODEL, INFO] = BUILDMODELFROMINPUTS(IN) converts the values typed in
%   the app to the SI engine model. It uses only the verified engine
%   functions (MESHSPANS, DEFINEMATERIAL, CREATEBEAMMODEL, FINDNODEATX,
%   ADDSUPPORT, ADDUNIFORMLOAD) and checks kinematic stability
%   (PARTITIONDOFS), so an unstable support layout fails here.
%   IN fields:
%     spans            span lengths [m]: numeric vector or text such as '20 20'
%     elementsPerSpan  elements in each span (positive integer)
%     supports         one entry per span end, as text such as
%                      'pin roller roller' or a cellstr. Each entry is
%                      'pin', 'roller', 'fixed' or 'none' (no support there).
%     materialType     'steel' or 'rcc'
%     E_GPa            elastic modulus [GPa] (Es or Ec)
%     I_m4             second moment of area [m^4] (Is, or Ieff for RCC)
%     materialName     optional display name
%     materialBasis    optional note on where E and I come from
%     udlDown_kNpm     optional permanent uniform load MAGNITUDE [kN/m] on
%                      every span, positive = downward, 0 = none
%   INFO fields:
%     supportX      span-end coordinates [m]
%     supportTypes  cellstr of the support entries
%     warnings      cellstr of unit-sanity warnings from DEFINEMATERIAL
%     summary       cellstr of human-readable lines describing the model
%
%   See also PARSENUMBERLIST, BRIDGECONDITIONAPP.

spans = parseNumberList(in.spans, 'Span lengths');
assertIntegerScalarInRange(in.elementsPerSpan, 'Elements per span', 1, 2000);
types = in.supports;
if isa(types, 'string')
    types = cellstr(types);
end
if ischar(types)
    types = regexp(strtrim(types), '[\s,;]+', 'split');
end
if ~iscellstr(types)
    error('BridgeFE:invalidInput', 'Supports must be typed as words such as ''pin roller''.');
end
types = lower(types(~cellfun(@isempty, types)));
types(strcmp(types, 'free')) = {'none'};
if numel(types) ~= numel(spans) + 1
    error('BridgeFE:invalidInput', ...
        'Give one support entry for each of the %d span ends (pin, roller, fixed or none); %d given.', ...
        numel(spans) + 1, numel(types));
end
known = {'pin', 'roller', 'fixed', 'none'};
for k = 1:numel(types)
    if ~any(strcmp(types{k}, known))
        error('BridgeFE:invalidSupportType', ...
            'Unknown support ''%s''. Use pin, roller, fixed or none.', types{k});
    end
end
name = '';
basis = '';
q = 0;
if isfield(in, 'materialName'), name = in.materialName; end
if isfield(in, 'materialBasis'), basis = in.materialBasis; end
if isfield(in, 'udlDown_kNpm'), q = in.udlDown_kNpm; end
assertPositiveFiniteScalar(in.E_GPa, 'E [GPa]');
assertPositiveFiniteScalar(in.I_m4, 'I [m^4]');
assertFiniteRealScalar(q, 'Uniform load [kN/m]');
if q < 0
    error('BridgeFE:invalidInput', 'Enter the uniform load as a downward magnitude (>= 0) in kN/m.');
end

[x, xs] = meshSpans(spans, in.elementsPerSpan);
lastwarn('');
material = defineMaterial(in.materialType, in.E_GPa * 1e9, in.I_m4, name, basis);
[warnMessage, warnId] = lastwarn;
warnings = {};
if strcmp(warnId, 'BridgeFE:unusualModulus')
    warnings = {warnMessage};
end
model = createBeamModel(x, material);
for k = 1:numel(types)
    if ~strcmp(types{k}, 'none')
        model = addSupport(model, findNodeAtX(model, xs(k)), types{k});
    end
end
if q > 0
    model = addUniformLoad(model, -q * 1e3);
end
partitionDofs(model);

supportText = cell(1, numel(types));
for k = 1:numel(types)
    supportText{k} = sprintf('%s at %g m', types{k}, xs(k));
end
nn = numel(x);
info.supportX = xs;
info.supportTypes = types(:);
info.warnings = warnings;
info.summary = { ...
    sprintf('Spans: %s m (total %g m)', strjoin(arrayfun(@(v) sprintf('%g', v), spans, 'UniformOutput', false), ' + '), sum(spans)); ...
    sprintf('Mesh: %d elements (%d per span), %d nodes, %d DOFs (v and theta at each node)', nn - 1, in.elementsPerSpan, nn, 2*nn); ...
    sprintf('Material: %s (%s): E = %g GPa, %s = %g m^4, EI = %.6g N*m^2', material.name, material.type, ...
        material.E / 1e9, material.inertiaLabel, material.I, material.EI); ...
    sprintf('Basis: %s', material.basis); ...
    sprintf('Supports: %s', strjoin(supportText, ', ')); ...
    sprintf('Permanent uniform load: %g kN/m downward', q)};
end

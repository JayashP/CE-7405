function [model, info] = buildModelFromTables(in, U)
%BUILDMODELFROMTABLES Beam model from the app's span and support tables (display units).
%   [MODEL, INFO] = BUILDMODELFROMTABLES(IN, U) converts the span table,
%   the support table, the material and the permanent load typed in the
%   app in the display units U (UNITSYSTEM, default SI) to the SI engine
%   model. It uses only the verified engine functions (MESHSPANS with one
%   element count per span, DEFINEMATERIAL, CREATEBEAMMODEL, FINDNODEATX,
%   ADDSUPPORT, ADDUNIFORMLOAD) and checks kinematic stability
%   (PARTITIONDOFS), so an unstable support layout fails here.
%   IN fields:
%     spanLengths      span lengths [U.length], one per row of the span table
%     elementsPerSpan  elements in each span (integers 1-2000), one per span
%     supportTypes     cellstr with one entry per span end (spans + 1),
%                      each a label of SUPPORTTYPELIST: 'Pin', 'Roller',
%                      'Fixed' or 'Free' (no support), case-insensitive
%     materialType     'steel' or 'rcc' (one material for all spans)
%     E                elastic modulus [U.modulus] (Es or Ec)
%     I                second moment of area [U.inertia] (Is, or Ieff for RCC)
%     udlDown          optional permanent uniform load MAGNITUDE
%                      [U.distributed] on every span, positive = downward,
%                      0 = none (the default)
%     materialName     optional display name
%     materialBasis    optional note on where E and I come from
%   The table columns may be numeric vectors or cell arrays of numbers.
%   An invalid entry throws an error that names its row, for example
%   'Span 2: length must be a positive number (m).' or 'Support C: unknown
%   type ''Hinge''. Use Pin, Roller, Fixed or Free.'
%   INFO fields:
%     supportX        span-end coordinates [m] (SI, as in the engine)
%     supportLetters  span-end names 'A', 'B', ... (SUPPORTLETTERS)
%     supportTypes    support labels ('Pin', 'Roller', 'Fixed' or 'Free')
%     warnings        cellstr of unit-sanity warnings from DEFINEMATERIAL
%     summary         cellstr of lines describing the model in units U:
%                     spans and total length, elements per span, supports
%                     with letters and x, material with E, I and EI
%                     [U.force*U.length^2], basis and permanent load
%
%   Example (two 66 ft steel spans in US customary units):
%     in = struct('spanLengths', [66 66], 'elementsPerSpan', [16 16], ...
%         'supportTypes', {{'Pin', 'Roller', 'Roller'}}, 'materialType', 'steel', ...
%         'E', 29000, 'I', 24000, 'udlDown', 1.2);
%     [model, info] = buildModelFromTables(in, unitSystem('US'));
%
%   See also BUILDMODELFROMINPUTS, SUPPORTTYPELIST, SUPPORTLETTERS,
%   UNITSYSTEM, VEHICLEFROMTABLE.

if nargin < 2 || isempty(U)
    U = unitSystem('SI');
end

% Span table: one row per span
spans = tableNumbers(in.spanLengths, 'Span lengths');
nSpans = numel(spans);
if nSpans == 0
    error('BridgeFE:invalidInput', 'Add at least one span to the span table.');
end
for k = 1:nSpans
    if ~(spans(k) > 0)
        error('BridgeFE:invalidInput', 'Span %d: length must be a positive number (%s).', k, U.length.unit);
    end
end
elements = tableNumbers(in.elementsPerSpan, 'Elements per span');
if numel(elements) ~= nSpans
    error('BridgeFE:invalidInput', 'Give the number of elements for each of the %d span(s); %d given.', ...
        nSpans, numel(elements));
end
for k = 1:nSpans
    if ~(elements(k) == round(elements(k)) && elements(k) >= 1 && elements(k) <= 2000)
        error('BridgeFE:invalidInput', 'Span %d: elements must be a whole number from 1 to 2000.', k);
    end
end

% Support table: one row per span end
letters = supportLetters(nSpans + 1);
types = in.supportTypes;
if isa(types, 'string')
    types = cellstr(types);
end
if ~iscell(types)
    error('BridgeFE:invalidInput', 'Support types must be a list (cell array) of Pin, Roller, Fixed or Free.');
end
if numel(types) ~= nSpans + 1
    error('BridgeFE:invalidInput', ...
        'Give one support type for each of the %d span ends (%s to %s); %d given.', ...
        nSpans + 1, letters{1}, letters{end}, numel(types));
end
[labels, engineTypes] = supportTypeList();
supportLabel = cell(nSpans + 1, 1);
supportType = cell(nSpans + 1, 1);
for k = 1:nSpans + 1
    t = types{k};
    if isa(t, 'string') && isscalar(t)
        t = char(t);
    end
    j = [];
    if ischar(t) && (isrow(t) || isempty(t))
        j = find(strcmpi(strtrim(t), labels), 1);
    end
    if isempty(j)
        if ischar(t) && (isrow(t) || isempty(t))
            error('BridgeFE:invalidSupportType', 'Support %s: unknown type ''%s''. Use Pin, Roller, Fixed or Free.', ...
                letters{k}, t);
        end
        error('BridgeFE:invalidSupportType', 'Support %s: unknown type. Use Pin, Roller, Fixed or Free.', letters{k});
    end
    supportLabel{k} = labels{j};
    supportType{k} = engineTypes{j};
end

% Material and permanent load
name = '';
basis = '';
q = 0;
if isfield(in, 'materialName'), name = in.materialName; end
if isfield(in, 'materialBasis'), basis = in.materialBasis; end
if isfield(in, 'udlDown'), q = in.udlDown; end
assertPositiveFiniteScalar(in.E, sprintf('E [%s]', U.modulus.unit));
assertPositiveFiniteScalar(in.I, sprintf('I [%s]', U.inertia.unit));
assertFiniteRealScalar(q, sprintf('Uniform load [%s]', U.distributed.unit));
if q < 0
    error('BridgeFE:invalidInput', 'Enter the uniform load as a downward magnitude (>= 0) in %s.', U.distributed.unit);
end
E = double(in.E);                 % an integer class would saturate when scaled to SI
I = double(in.I);
q = double(q);

% SI engine model
[x, xs] = meshSpans(spans * U.length.toSI, elements);
lastwarn('', '');                 % clear both the message and the identifier
material = defineMaterial(in.materialType, E * U.modulus.toSI, I * U.inertia.toSI, name, basis);
[warnMessage, warnId] = lastwarn;
warnings = {};
if strcmp(warnId, 'BridgeFE:unusualModulus')
    warnings = {warnMessage};
end
model = createBeamModel(x, material);
for k = 1:nSpans + 1
    if ~strcmp(supportType{k}, 'none')
        model = addSupport(model, findNodeAtX(model, xs(k)), supportType{k});
    end
end
if q > 0
    model = addUniformLoad(model, -q * U.distributed.toSI);
end
partitionDofs(model);

% Summary in display units (positions from the typed lengths, not converted back)
lu = U.length.unit;
xDisplay = [0, cumsum(spans)];
supportText = cell(1, nSpans + 1);
for k = 1:nSpans + 1
    supportText{k} = sprintf('%s %s (x = %g %s)', letters{k}, supportLabel{k}, xDisplay(k), lu);
end
nn = numel(x);
EIunit = sprintf('%s*%s^2', U.force.unit, U.length.unit);
EIdisplay = material.EI / (U.force.toSI * U.length.toSI^2);
info.supportX = xs;
info.supportLetters = letters(:);
info.supportTypes = supportLabel;
info.warnings = warnings;
info.summary = { ...
    sprintf('Spans: %s %s (total %g %s)', numberText(spans, ' + '), lu, sum(spans), lu); ...
    sprintf('Mesh: %s elements per span (%d elements, %d nodes, %d DOFs: v and theta at each node)', ...
        numberText(elements, ' + '), nn - 1, nn, 2*nn); ...
    sprintf('Supports: %s', strjoin(supportText, ', ')); ...
    sprintf('Material: %s (%s): E = %g %s, %s = %g %s, EI = %.6g %s', material.name, material.type, ...
        E, U.modulus.unit, material.inertiaLabel, I, U.inertia.unit, EIdisplay, EIunit); ...
    sprintf('Basis: %s', material.basis); ...
    sprintf('Permanent uniform load: %g %s downward', q, U.distributed.unit)};
end

function v = tableNumbers(values, name)
% Row vector of a table column; entries that are not real, finite numbers become NaN.
if isempty(values)
    v = zeros(1, 0);
elseif iscell(values)
    v = NaN(1, numel(values));
    for k = 1:numel(values)
        c = values{k};
        if isnumeric(c) && isscalar(c) && isreal(c) && isfinite(c)
            v(k) = double(c);
        end
    end
elseif isnumeric(values) && isreal(values)
    v = double(values(:).');
    v(~isfinite(v)) = NaN;
else
    error('BridgeFE:invalidInput', '%s must be a list of numbers (one per table row).', name);
end
end

function text = numberText(values, separator)
text = strjoin(arrayfun(@(v) sprintf('%g', v), values, 'UniformOutput', false), separator);
end

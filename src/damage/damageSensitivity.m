function s = damageSensitivity(model, vehicle, d, quantity, varargin)
%DAMAGESENSITIVITY Move one prescribed stiffness loss across the beam and rank the locations.
%   S = DAMAGESENSITIVITY(MODEL, VEHICLE, D, QUANTITY, NAME, VALUE, ...)
%   applies the loss D (0 < D < 1) to one group of elements at a time, runs
%   RUNMOVINGLOAD with VEHICLE for each damaged model and records the global
%   extreme QUANTITY (PROJECT_SPEC.md section 6, sensitivity sweep):
%     'Mmax' 'Mmin' 'Vmax' 'Vmin' 'vmax' 'vmin'   critical moment, shear or
%                                                 deflection (vmin = largest
%                                                 downward deflection)
%     'Rmax' 'Rmin'                               vertical reaction at the
%                                                 node given by option 'Node'
%   Options:
%     'Groups'  cell array of element index vectors, one per candidate
%               location (default: each element on its own)
%     'Node'    support node for 'Rmax' / 'Rmin'
%     any other NAME/VALUE pair is passed to RUNMOVINGLOAD (e.g. 'Step', 'Refine')
%   Any damage already in MODEL is kept, and the swept loss replaces it
%   inside each group.
%
%   S fields: quantity, d, groups, healthy (value without the swept loss),
%   values (one per group), change (values - healthy), pctChange
%   (RELATIVECHANGE, NaN for a zero healthy value), rank (group indices
%   sorted by |change|, largest first).
%   The ranking is a forward sensitivity of the MODEL. It does not say where
%   real damage is (that is the Stage 3 inverse problem).
%
%   See also APPLYSTIFFNESSDAMAGE, COMPAREHEALTHYDAMAGED, RUNMOVINGLOAD.

validateModel(model);
ne = size(model.elements.conn, 1);
groups = num2cell((1:ne)');
node = [];
passOn = {};
for k = 1:2:numel(varargin)
    switch varargin{k}
        case 'Groups'
            groups = varargin{k + 1};
        case 'Node'
            node = varargin{k + 1};
        otherwise
            passOn = [passOn, varargin(k:k+1)]; %#ok<AGROW>
    end
end
if ~(isnumeric(d) && isscalar(d) && d > 0 && d < 1)
    error('BridgeFE:invalidInput', 'd must be a scalar with 0 < d < 1.');
end
known = {'Mmax', 'Mmin', 'Vmax', 'Vmin', 'vmax', 'vmin', 'Rmax', 'Rmin'};
if ~(ischar(quantity) && any(strcmp(quantity, known)))
    error('BridgeFE:invalidInput', 'quantity must be one of: %s.', strjoin(known, ', '));
end
if any(strcmp(quantity, {'Rmax', 'Rmin'}))
    if isempty(node) || ~any(model.supports.node == node)
        error('BridgeFE:invalidInput', 'For %s give option ''Node'' with a supported node.', quantity);
    end
end
if ~iscell(groups) || isempty(groups)
    error('BridgeFE:invalidInput', 'Groups must be a non-empty cell array of element index vectors.');
end

s.quantity = quantity;
s.d = d;
s.groups = groups(:);
s.healthy = extract(runMovingLoad(model, vehicle, passOn{:}), quantity, node);
s.values = zeros(numel(groups), 1);
for g = 1:numel(groups)
    damaged = applyStiffnessDamage(model, groups{g}, d);
    s.values(g) = extract(runMovingLoad(damaged, vehicle, passOn{:}), quantity, node);
end
s.change = s.values - s.healthy;
s.pctChange = relativeChange(s.healthy * ones(size(s.values)), s.values, max(abs([s.healthy; s.values])));
[~, s.rank] = sort(abs(s.change), 'descend');
end

function value = extract(ml, quantity, node)
switch quantity
    case {'Rmax', 'Rmin'}
        k = find(ml.reactions.node == node & strcmp(ml.reactions.component, 'Fv'));
        if strcmp(quantity, 'Rmax')
            value = ml.reactions.Rmax(k);
        else
            value = ml.reactions.Rmin(k);
        end
    otherwise
        q = quantity(1);
        extreme = quantity(2:end);
        k = find(strcmp({ml.critical.quantity}, q) & strcmp({ml.critical.extreme}, extreme));
        value = ml.critical(k).value;
end
end

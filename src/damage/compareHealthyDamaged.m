function cmp = compareHealthyDamaged(healthy, damaged, vehicle, varargin)
%COMPAREHEALTHYDAMAGED Healthy vs damaged moving-load results for the same vehicle (Stage 2).
%   CMP = COMPAREHEALTHYDAMAGED(HEALTHY, DAMAGED, VEHICLE, NAME, VALUE, ...)
%   runs RUNMOVINGLOAD on both models with the same VEHICLE and options
%   (passed on unchanged, e.g. 'Step', 'Direction', 'Refine') and compares
%   them. The two models must have the same geometry, supports and stations.
%   Usually DAMAGED = APPLYSTIFFNESSDAMAGE(HEALTHY, ...). Percent changes use
%   RELATIVECHANGE: NaN where the healthy value is zero, in which case use the
%   absolute change (PROJECT_SPEC.md section 6).
%
%   CMP fields:
%     healthy, damaged   the two RUNMOVINGLOAD results
%     stations           envelope coordinates [m]
%     envelopeChange     damaged - healthy envelope at each station for
%                        Mmax, Mmin, Vmax, Vmin, vmax, vmin (SI units)
%     critical           struct array, one row per global extreme: quantity,
%                        extreme, healthy, damaged, change, pctChange,
%                        healthyXv, damagedXv (the governing vehicle
%                        position may move), healthyX, damagedX
%     reactions          struct array, one row per restrained DOF: node,
%                        component, healthyMax, damagedMax, changeMax,
%                        pctChangeMax, and the same for Min
%     damagedElements    indices of elements with stiffness factor < 1
%
%   For a statically determinate beam, reactions and moments do not change
%   (only deflections do). For a continuous or propped beam they redistribute
%   (spec section 6).
%
%   See also APPLYSTIFFNESSDAMAGE, RUNMOVINGLOAD, DAMAGESENSITIVITY.

validateModel(healthy);
validateModel(damaged);
if ~(isequal(healthy.nodes.x, damaged.nodes.x) && isequal(healthy.supports, damaged.supports))
    error('BridgeFE:invalidInput', 'Healthy and damaged models must have the same nodes and supports.');
end
mh = runMovingLoad(healthy, vehicle, varargin{:});
md = runMovingLoad(damaged, vehicle, varargin{:});

cmp.healthy = mh;
cmp.damaged = md;
cmp.stations = mh.stations;
names = {'Mmax', 'Mmin', 'Vmax', 'Vmin', 'vmax', 'vmin'};
for k = 1:numel(names)
    cmp.envelopeChange.(names{k}) = md.envelope.(names{k}) - mh.envelope.(names{k});
end

scales = struct('M', max(abs([mh.envelope.Mmax; mh.envelope.Mmin])), ...
    'V', max(abs([mh.envelope.Vmax; mh.envelope.Vmin])), 'v', max(abs([mh.envelope.vmax; mh.envelope.vmin])));
critical = struct('quantity', {}, 'extreme', {}, 'healthy', {}, 'damaged', {}, 'change', {}, 'pctChange', {}, ...
    'healthyXv', {}, 'damagedXv', {}, 'healthyX', {}, 'damagedX', {});
for k = 1:numel(mh.critical)
    h = mh.critical(k);
    d = md.critical(k);
    critical(k) = struct('quantity', h.quantity, 'extreme', h.extreme, 'healthy', h.value, 'damaged', d.value, ...
        'change', d.value - h.value, 'pctChange', relativeChange(h.value, d.value, scales.(h.quantity)), ...
        'healthyXv', h.xv, 'damagedXv', d.xv, 'healthyX', h.x, 'damagedX', d.x);
end
cmp.critical = critical;

r = mh.reactions;
s = md.reactions;
rScale = max(abs([r.Rmax; r.Rmin]));
reactions = struct('node', {}, 'component', {}, 'healthyMax', {}, 'damagedMax', {}, 'changeMax', {}, ...
    'pctChangeMax', {}, 'healthyMin', {}, 'damagedMin', {}, 'changeMin', {}, 'pctChangeMin', {});
for k = 1:numel(r.dof)
    reactions(k) = struct('node', r.node(k), 'component', r.component{k}, ...
        'healthyMax', r.Rmax(k), 'damagedMax', s.Rmax(k), 'changeMax', s.Rmax(k) - r.Rmax(k), ...
        'pctChangeMax', relativeChange(r.Rmax(k), s.Rmax(k), rScale), ...
        'healthyMin', r.Rmin(k), 'damagedMin', s.Rmin(k), 'changeMin', s.Rmin(k) - r.Rmin(k), ...
        'pctChangeMin', relativeChange(r.Rmin(k), s.Rmin(k), rScale));
end
cmp.reactions = reactions;
cmp.damagedElements = find(damaged.elements.stiffnessFactor < 1);
end

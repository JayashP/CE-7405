function ml = runMovingLoad(model, vehicle, varargin)
%RUNMOVINGLOAD Quasi-static moving-load analysis: envelopes and critical vehicle positions.
%   ML = RUNMOVINGLOAD(MODEL, VEHICLE) moves VEHICLE (CREATEVEHICLE) across
%   MODEL in equal steps (GENERATEVEHICLEPOSITIONS), solves every position
%   with one stored factorization (PREPAREMOVINGLOAD, ANALYZEVEHICLEPOSITION),
%   and returns response envelopes and critical vehicle positions
%   (PROJECT_SPEC.md sections 5.1 and 5.3, DECISIONS.md D-019 to D-021).
%   Permanent loads already in MODEL are included at every position; pass a
%   model without loads for live-load-only envelopes. This is a sequence of
%   static solutions, with no dynamic or impact effects.
%
%   ML = RUNMOVINGLOAD(..., NAME, VALUE) options:
%     'Step'               requested position step [m], default 0.1
%     'Direction'          +1 (toward +x, default) or -1 (toward -x)
%     'Stations'           envelope coordinates [m]; default = the nodes plus
%                          'StationsPerElement' equal divisions per element
%     'StationsPerElement' default 4
%     'Refine'             true (default): after the coarse sweep, re-analyse
%                          positions within +/- one step of each critical
%                          position at step/'RefineFactor'
%     'RefineFactor'       default 10
%
%   ML fields:
%     vehicle, direction, requestedStep, step (actual coarse step), refineFactor
%     positions       every analysed front-axle position x_v [m] (sorted)
%     nCoarse, nRefined
%     stations        envelope coordinates [m]
%     envelope        at every station, over all positions:
%                     Mmax, Mmin [N*m]; Vmax, Vmin [N] (both sides of any jump);
%                     vmax, vmin [m]; and the governing x_v of each
%                     (MmaxXv, MminXv, VmaxXv, VminXv, vmaxXv, vminXv)
%     reactions       per restrained DOF: dof, node, component ('Fv' or 'Mz'),
%                     Rmax, RmaxXv, Rmin, RminXv
%     critical        struct array, one row per quantity M, V, v and extreme
%                     max/min, with fields quantity, extreme, value, x (where
%                     the response occurs), xv (vehicle position causing it),
%                     axleX (axle coordinates on the beam at that position),
%                     coarseValue, coarseXv (before refinement). The search
%                     covers the stations AND the points under every axle.
%     units
%   The envelope at each station and the single position that governs a
%   global extreme are different things (spec section 5.3); both are given.
%
%   Example (spec 3-axle illustrative truck on a 20 m simple span):
%     truck = createVehicle([80e3 120e3 120e3], [4.2 1.4]);
%     ml = runMovingLoad(model, truck, 'Step', 0.1);
%     ml.critical(1)          % largest sagging moment, where and for which x_v
%     plot(ml.stations, ml.envelope.Mmax, ml.stations, ml.envelope.Mmin)
%
%   See also CREATEVEHICLE, ANALYZEVEHICLEPOSITION, PREPAREMOVINGLOAD.

opts = parseOptions(varargin);
validateModel(model);
validateVehicle(vehicle);
x = model.nodes.x;
if isempty(opts.Stations)
    stations = defaultEnvelopeStations(x, opts.StationsPerElement);
else
    stations = unique(opts.Stations(:));
end
prep = prepareMovingLoad(model, stations);
[xvCoarse, step] = generateVehiclePositions(model, vehicle, opts.Step, opts.Direction);

T = initTrackers(prep);
for k = 1:numel(xvCoarse)
    T = updateTrackers(T, analyzeVehiclePosition(prep, vehicle, xvCoarse(k), opts.Direction), prep);
end
coarseCritical = T.critical;
analysed = xvCoarse;
nRefined = 0;

if opts.Refine
    assertIntegerScalarInRange(opts.RefineFactor, 'RefineFactor', 2, Inf);
    centers = [[T.critical.xv], T.reactions.RmaxXv(:).', T.reactions.RminXv(:).'];
    centers = unique(centers(isfinite(centers)));
    h = step / opts.RefineFactor;
    offsets = h * (-opts.RefineFactor:opts.RefineFactor);
    candidates = unique(bsxfun(@plus, centers(:), offsets));
    lo = min(xvCoarse);
    hi = max(xvCoarse);
    candidates = candidates(candidates >= lo & candidates <= hi);
    span = hi - lo;
    isNew = true(size(candidates));
    for k = 1:numel(candidates)
        isNew(k) = min(abs(analysed - candidates(k))) > 1e-9 * max(span, 1);
    end
    candidates = candidates(isNew);
    for k = 1:numel(candidates)
        T = updateTrackers(T, analyzeVehiclePosition(prep, vehicle, candidates(k), opts.Direction), prep);
    end
    analysed = [analysed; candidates];
    nRefined = numel(candidates);
end

for k = 1:numel(T.critical)
    T.critical(k).coarseValue = coarseCritical(k).value;
    T.critical(k).coarseXv = coarseCritical(k).xv;
end

ml.vehicle = vehicle;
ml.direction = opts.Direction;
ml.requestedStep = opts.Step;
ml.step = step;
ml.refineFactor = opts.RefineFactor;
ml.positions = sort(analysed);
ml.nCoarse = numel(xvCoarse);
ml.nRefined = nRefined;
ml.stations = prep.stations.x;
ml.envelope = T.envelope;
ml.reactions = T.reactions;
ml.critical = T.critical;
ml.units = model.units;
end

function opts = parseOptions(args)
opts = struct('Step', 0.1, 'Direction', 1, 'Stations', [], 'StationsPerElement', 4, ...
    'Refine', true, 'RefineFactor', 10);
if mod(numel(args), 2) ~= 0
    error('BridgeFE:invalidInput', 'Options must be NAME, VALUE pairs.');
end
names = fieldnames(opts);
for k = 1:2:numel(args)
    match = strcmpi(names, args{k});
    if ~ischar(args{k}) || ~any(match)
        error('BridgeFE:invalidInput', 'Unknown option ''%s''.', num2str(args{k}));
    end
    opts.(names{match}) = args{k + 1};
end
if ~(isnumeric(opts.Direction) && isscalar(opts.Direction) && (opts.Direction == 1 || opts.Direction == -1))
    error('BridgeFE:invalidInput', 'Direction must be +1 or -1.');
end
if ~(islogical(opts.Refine) || isnumeric(opts.Refine)) || ~isscalar(opts.Refine)
    error('BridgeFE:invalidInput', 'Refine must be true or false.');
end
opts.Refine = logical(opts.Refine);
end

function T = initTrackers(prep)
nS = numel(prep.stations.x);
inf1 = Inf(nS, 1);
nan1 = NaN(nS, 1);
T.envelope = struct('Mmax', -inf1, 'MmaxXv', nan1, 'Mmin', inf1, 'MminXv', nan1, ...
    'Vmax', -inf1, 'VmaxXv', nan1, 'Vmin', inf1, 'VminXv', nan1, ...
    'vmax', -inf1, 'vmaxXv', nan1, 'vmin', inf1, 'vminXv', nan1);
dofs = prep.restrainedDofs(:);
nR = numel(dofs);
component = repmat({'Fv'}, nR, 1);
component(mod(dofs, 2) == 0) = {'Mz'};
T.reactions.dof = dofs;
T.reactions.node = ceil(dofs / 2);
T.reactions.component = component;
T.reactions.Rmax = -Inf(nR, 1);
T.reactions.RmaxXv = NaN(nR, 1);
T.reactions.Rmin = Inf(nR, 1);
T.reactions.RminXv = NaN(nR, 1);
quantities = {'M', 'M', 'V', 'V', 'v', 'v'};
extremes = {'max', 'min', 'max', 'min', 'max', 'min'};
for k = 1:6
    if strcmp(extremes{k}, 'max')
        start = -Inf;
    else
        start = Inf;
    end
    T.critical(k) = struct('quantity', quantities{k}, 'extreme', extremes{k}, 'value', start, ...
        'x', NaN, 'xv', NaN, 'axleX', zeros(1, 0), 'coarseValue', NaN, 'coarseXv', NaN);
end
end

function T = updateTrackers(T, res, prep)
st = res.stations;
ap = res.axlePoints;
xv = res.xv;
env = T.envelope;
[env.Mmax, env.MmaxXv] = keepMax(env.Mmax, env.MmaxXv, max(st.ML, st.MR), xv);
[env.Mmin, env.MminXv] = keepMin(env.Mmin, env.MminXv, min(st.ML, st.MR), xv);
[env.Vmax, env.VmaxXv] = keepMax(env.Vmax, env.VmaxXv, max(st.VL, st.VR), xv);
[env.Vmin, env.VminXv] = keepMin(env.Vmin, env.VminXv, min(st.VL, st.VR), xv);
[env.vmax, env.vmaxXv] = keepMax(env.vmax, env.vmaxXv, st.v, xv);
[env.vmin, env.vminXv] = keepMin(env.vmin, env.vminXv, st.v, xv);
T.envelope = env;

Rc = res.R(prep.restrainedDofs);
[T.reactions.Rmax, T.reactions.RmaxXv] = keepMax(T.reactions.Rmax, T.reactions.RmaxXv, Rc, xv);
[T.reactions.Rmin, T.reactions.RminXv] = keepMin(T.reactions.Rmin, T.reactions.RminXv, Rc, xv);

% Global extremes over stations and points under the axles.
xAll = [st.x; st.x; ap.x; ap.x];
values = {[st.ML; st.MR; ap.ML; ap.MR], [st.VL; st.VR; ap.VL; ap.VR], [st.v; st.v; ap.v; ap.v]};
axleX = res.axles.x(res.axles.onBridge).';
for k = 1:6
    vals = values{ceil(k / 2)};
    if strcmp(T.critical(k).extreme, 'max')
        [best, i] = max(vals);
        better = best > T.critical(k).value;
    else
        [best, i] = min(vals);
        better = best < T.critical(k).value;
    end
    if better
        T.critical(k).value = best;
        T.critical(k).x = xAll(i);
        T.critical(k).xv = xv;
        T.critical(k).axleX = axleX;
    end
end
end

function [current, at] = keepMax(current, at, candidate, xv)
better = candidate > current;
current(better) = candidate(better);
at(better) = xv;
end

function [current, at] = keepMin(current, at, candidate, xv)
better = candidate < current;
current(better) = candidate(better);
at(better) = xv;
end

function prep = prepareMovingLoad(model, stations)
%PREPAREMOVINGLOAD Precompute everything that stays constant while a vehicle moves.
%   PREP = PREPAREMOVINGLOAD(MODEL, STATIONS) does the position-independent
%   work once, so that each vehicle position only needs a load vector and
%   two triangular solves (DECISIONS.md D-020):
%     - assembles K and the element matrices, partitions the DOFs (with the
%       under-restraint check) and factorizes Kff = Rc'*Rc (Cholesky);
%     - stores the PERMANENT loads already in MODEL (nodal, uniform and point
%       loads). They act at every vehicle position (superposition); pass a
%       model without loads for live-load-only results;
%     - maps the envelope STATIONS [m] to elements for left/right limits.
%   STATIONS must lie on the beam. PREP is used by ANALYZEVEHICLEPOSITION.
%
%   See also ANALYZEVEHICLEPOSITION, RUNMOVINGLOAD.

validateModel(model);
x = model.nodes.x;
tol = 1e-9 * (x(end) - x(1));
if ~(isnumeric(stations) && isreal(stations) && isvector(stations) && all(isfinite(stations)))
    error('BridgeFE:invalidInput', 'stations must be a real, finite vector of coordinates [m].');
end
stations = stations(:);
if any(stations < x(1) - tol | stations > x(end) + tol)
    error('BridgeFE:offBeam', 'stations must lie within the beam [%g, %g] m.', x(1), x(end));
end
stations = min(max(stations, x(1)), x(end));

[K, ke] = assembleGlobalK(model);
[freeDofs, restrainedDofs] = partitionDofs(model);
Kff = K(freeDofs, freeDofs);
Rc = [];
rcondKff = Inf;
if ~isempty(freeDofs)
    [Rc, p] = chol(Kff);
    if p ~= 0
        error('BridgeFE:notPositiveDefinite', 'Reduced stiffness matrix is not positive definite.');
    end
    rcondKff = rcond(full(Kff));
end

prep.x = x;
prep.tol = tol;
prep.Le = diff(x);
prep.EI = model.elements.EI;
prep.w = model.loads.elementUDL;
prep.dofMap = elementDofs(model.elements.conn);
prep.ke = ke;
prep.K = K;
prep.freeDofs = freeDofs;
prep.restrainedDofs = restrainedDofs;
prep.Rc = Rc;
prep.rcondKff = rcondKff;
prep.Kc = K(restrainedDofs, :);
prep.Fbase = assembleLoadVector(model);
prep.f0base = elementLoadVectors(model);
loc = locatePointLoads(model);
inside = loc.element > 0;
prep.basePoint.e = loc.element(inside);
prep.basePoint.a = loc.a(inside);
prep.basePoint.P = loc.P(inside);
prep.stations = mapCoordinatesToElements(x, stations, tol);
prep.stations.x = stations;
prep.units = model.units;
end

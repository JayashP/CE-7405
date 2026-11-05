function validateModel(model)
%VALIDATEMODEL Check a bending-beam model struct for consistency.
%   VALIDATEMODEL(MODEL) returns silently if MODEL is a valid model (see
%   CREATEBEAMMODEL) and otherwise throws 'BridgeFE:invalidModel' with a
%   message describing the first problem found. It checks:
%     - all required fields exist;
%     - node coordinates are real, finite and strictly increasing;
%     - connectivity is one continuous chain [(1:ne)' (2:ne+1)'] (Option A:
%       a single equivalent beam, no internal hinges or overlaps);
%     - EI is real, finite and positive for every element;
%     - material records are valid (VALIDATEMATERIAL), and every element
%       that points to a material has EI = E*I of that material;
%     - supports sit on existing nodes, at most one per node, with restraint
%       flags that match their type;
%     - nodal loads act on existing nodes with real, finite values;
%     - the uniform element load intensities are a real, finite NE-by-1 vector;
%     - point loads are a real, finite NP-by-2 [x Fv] matrix with every x on
%       the beam (within 1e-9 times its length).
%   Kinematic stability is checked separately by PARTITIONDOFS.
%
%   See also CREATEBEAMMODEL, PARTITIONDOFS.

id = 'BridgeFE:invalidModel';

if ~(isstruct(model) && isscalar(model))
    error(id, 'model must be a scalar struct created by createBeamModel.');
end
required = {{'nodes', 'x'}, {'elements', 'conn'}, {'elements', 'EI'}, ...
    {'supports', 'node'}, {'supports', 'type'}, {'supports', 'restraint'}, ...
    {'loads', 'nodal'}, {'loads', 'elementUDL'}, {'loads', 'point'}, {'elements', 'materialId'}, {'elements', 'stiffnessFactor'}};
for k = 1:numel(required)
    p = required{k};
    if ~(isfield(model, p{1}) && isstruct(model.(p{1})) && isfield(model.(p{1}), p{2}))
        error(id, 'model.%s.%s is missing.', p{1}, p{2});
    end
end

% Nodes
x = model.nodes.x;
if ~(isnumeric(x) && isreal(x) && iscolumn(x) && numel(x) >= 2 && all(isfinite(x)))
    error(id, 'model.nodes.x must be a real, finite column vector with at least 2 entries [m].');
end
if any(diff(x) <= 0)
    error(id, 'model.nodes.x must be strictly increasing.');
end
nn = numel(x);
ne = nn - 1;

% Elements
conn = model.elements.conn;
if ~(isnumeric(conn) && isequal(size(conn), [ne, 2]) && isequal(conn, [(1:ne)', (2:nn)']))
    error(id, ['model.elements.conn must be [(1:ne)'' (2:ne+1)'']: one continuous beam ' ...
        'whose elements join consecutive nodes.']);
end
EI = model.elements.EI;
if ~(isnumeric(EI) && isreal(EI) && isequal(size(EI), [ne, 1]) && all(isfinite(EI)) && all(EI > 0))
    error(id, 'model.elements.EI must be a real, finite, positive %d-by-1 vector [N*m^2].', ne);
end

% Stiffness factors (1 - d, Stage 2 damage)
sf = model.elements.stiffnessFactor;
if ~(isnumeric(sf) && isreal(sf) && isequal(size(sf), [ne, 1]) && all(sf > 0) && all(sf <= 1))
    error(id, 'model.elements.stiffnessFactor must be a %d-by-1 vector with 0 < factor <= 1 (factor = 1 - d).', ne);
end

% Materials
if ~(isfield(model, 'materials') && isstruct(model.materials))
    error(id, 'model.materials is missing.');
end
nm = numel(model.materials);
for k = 1:nm
    try
        validateMaterial(model.materials(k));
    catch err
        error(id, 'model.materials(%d) is invalid: %s', k, err.message);
    end
end
mid = model.elements.materialId;
if ~(isnumeric(mid) && isreal(mid) && isequal(size(mid), [ne, 1]) && all(mid == round(mid)) ...
        && all(mid >= 0) && all(mid <= nm))
    error(id, 'model.elements.materialId must be a %d-by-1 vector of integers between 0 and %d.', ne, nm);
end
for e = find(mid > 0).'
    mat = model.materials(mid(e));
    if abs(EI(e) - mat.EI) > 1e-12 * mat.EI
        error(id, ['EI of element %d (%g N*m^2) differs from its material ''%s'' (E*I = %g N*m^2). ' ...
            'Change materials with assignMaterial instead of editing EI.'], e, EI(e), mat.name, mat.EI);
    end
end

% Supports
sn = model.supports.node;
st = model.supports.type;
sr = model.supports.restraint;
ns = numel(sn);
if ~(isnumeric(sn) && isreal(sn) && size(sn, 2) <= 1 && all(isfinite(sn)) ...
        && all(sn == round(sn)) && all(sn >= 1) && all(sn <= nn))
    error(id, 'model.supports.node must be a column of integer node indices between 1 and %d.', nn);
end
sortedNodes = sort(sn);
duplicate = sortedNodes(find(diff(sortedNodes) == 0, 1));
if ~isempty(duplicate)
    error(id, 'Node %d carries more than one support.', duplicate);
end
if ~(iscellstr(st) && numel(st) == ns)
    error(id, 'model.supports.type must be a cellstr with one entry per support.');
end
if ~((islogical(sr) || isnumeric(sr)) && isequal(size(sr), [ns, 2]))
    error(id, 'model.supports.restraint must be an NS-by-2 [v theta] flag matrix.');
end
for s = 1:ns
    if ~isequal(logical(sr(s, :)), supportRestraint(st{s}))
        error(id, 'Restraint flags of the support at node %d do not match its type ''%s''.', ...
            sn(s), st{s});
    end
end

% Nodal loads
Ln = model.loads.nodal;
if ~(isnumeric(Ln) && isreal(Ln) && ndims(Ln) == 2 && size(Ln, 2) == 3 && all(isfinite(Ln(:))))
    error(id, 'model.loads.nodal must be a real, finite NL-by-3 matrix [node Fv Mz].');
end
loadNodes = Ln(:, 1);
if any(loadNodes ~= round(loadNodes)) || any(loadNodes < 1) || any(loadNodes > nn)
    error(id, 'model.loads.nodal(:,1) must contain integer node indices between 1 and %d.', nn);
end

% Uniform element loads
w = model.loads.elementUDL;
if ~(isnumeric(w) && isreal(w) && isequal(size(w), [ne, 1]) && all(isfinite(w)))
    error(id, 'model.loads.elementUDL must be a real, finite %d-by-1 vector [N/m].', ne);
end

% Point loads at arbitrary coordinates
Lp = model.loads.point;
if ~(isnumeric(Lp) && isreal(Lp) && ndims(Lp) == 2 && size(Lp, 2) == 2 && all(isfinite(Lp(:))))
    error(id, 'model.loads.point must be a real, finite NP-by-2 matrix [x Fv].');
end
tol = 1e-9 * (x(end) - x(1));
if any(Lp(:, 1) < x(1) - tol | Lp(:, 1) > x(end) + tol)
    error(id, 'model.loads.point has a load outside the beam [%g, %g] m.', x(1), x(end));
end
end

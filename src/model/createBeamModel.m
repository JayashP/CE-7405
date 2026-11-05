function model = createBeamModel(x, EI)
%CREATEBEAMMODEL Build a 2D equivalent bending-beam model from node coordinates.
%   MODEL = CREATEBEAMMODEL(X, EI) creates one continuous beam whose nodes
%   lie at the coordinates X [m] (strictly increasing, measured from the
%   left end) and whose NE = numel(X)-1 elements join consecutive nodes.
%   EI [N*m^2] is a scalar (same for every element) or an NE-element vector
%   of per-element flexural rigidities (steel Es*Is or RCC Ec*Ieff).
%   MODEL = CREATEBEAMMODEL(X, MATERIAL) uses a steel or RCC material from
%   DEFINEMATERIAL for every element (EI = E*I) and records it. Use
%   ASSIGNMATERIAL to give spans different materials.
%
%   The struct stores input data only; derived quantities such as element
%   lengths are recomputed where needed so they cannot become stale:
%     model.nodes.x            NN-by-1 node coordinates [m]
%     model.elements.conn      NE-by-2 node indices [i j], i = left node
%     model.elements.EI        NE-by-1 flexural rigidity [N*m^2]
%     model.elements.materialId NE-by-1 index into model.materials, 0 when EI
%                              was given directly as a number
%     model.supports.node      NS-by-1 supported node indices
%     model.supports.type      NS-by-1 cellstr: 'pin' | 'roller' | 'fixed'
%     model.supports.restraint NS-by-2 logical [v theta] restraint flags
%     model.loads.nodal        NL-by-3 [node, Fv [N] (+ up), Mz [N*m] (+ CCW)]
%     model.loads.elementUDL   NE-by-1 uniform load intensity w [N/m] on each
%                              element (+ up; a downward load is negative)
%     model.loads.point        NP-by-2 [x [m], Fv [N] (+ up)] point loads at any
%                              coordinate, not necessarily a node (ADDPOINTLOAD)
%     model.units              labels of the internal SI units (D-002)
%     model.conventions        sign-convention labels (D-003)
%     model.elements.stiffnessFactor NE-by-1, 1 - d for a prescribed stiffness
%                              loss d (APPLYSTIFFNESSDAMAGE); 1 = healthy
%     model.materials          struct array of material records (DEFINEMATERIAL)
%     model.meta               model format version
%
%   Add supports with ADDSUPPORT, nodal loads with ADDNODALLOAD, uniform
%   element loads with ADDUNIFORMLOAD and point loads anywhere along the
%   beam with ADDPOINTLOAD. MESHSPANS builds node coordinates for
%   multi-span beams with a node at every support.
%
%   Example (20 m simply supported span, 20 elements, E = 200 GPa, I = 0.01 m^4):
%     model = createBeamModel(generateUniformMesh(20, 20), 200e9 * 0.01);
%     model = addSupport(model, 1, 'pin');
%     model = addSupport(model, 21, 'roller');
%
%   See also GENERATEUNIFORMMESH, MESHSPANS, DEFINEMATERIAL, ASSIGNMATERIAL,
%   ADDSUPPORT, ADDNODALLOAD,
%   ADDUNIFORMLOAD, ADDPOINTLOAD, VALIDATEMODEL.

if ~(isnumeric(x) && isreal(x) && isvector(x) && numel(x) >= 2 && all(isfinite(x)))
    error('BridgeFE:invalidInput', ...
        'x must be a real, finite vector of at least 2 node coordinates [m].');
end
x = double(x(:));
if any(diff(x) <= 0)
    error('BridgeFE:invalidInput', ...
        'x must be strictly increasing (zero-length or reversed elements are not allowed).');
end
ne = numel(x) - 1;

materials = struct('type', {}, 'name', {}, 'E', {}, 'I', {}, 'EI', {}, 'inertiaLabel', {}, 'basis', {});
materialId = zeros(ne, 1);
if isstruct(EI)
    validateMaterial(EI);
    materials(1) = EI;
    materialId = ones(ne, 1);
    EI = EI.EI;
end
if ~(isnumeric(EI) && isreal(EI) && all(isfinite(EI(:))) && all(EI(:) > 0) ...
        && (isscalar(EI) || (isvector(EI) && numel(EI) == ne)))
    error('BridgeFE:invalidInput', ...
        'EI must be a real, finite, positive scalar or a vector with one value per element (%d) [N*m^2].', ne);
end
if isscalar(EI)
    EI = repmat(EI, ne, 1);
end

model.nodes.x = x;
model.elements.conn = [(1:ne)', (2:ne+1)'];
model.elements.EI = double(EI(:));
model.elements.materialId = materialId;
model.elements.stiffnessFactor = ones(ne, 1);
model.materials = materials;
model.supports.node = zeros(0, 1);
model.supports.type = cell(0, 1);
model.supports.restraint = false(0, 2);
model.loads.nodal = zeros(0, 3);
model.loads.elementUDL = zeros(ne, 1);
model.loads.point = zeros(0, 2);
model.units = struct('length', 'm', 'force', 'N', 'moment', 'N*m', ...
    'rotation', 'rad', 'EI', 'N*m^2');
model.conventions = struct( ...
    'x', 'positive to the right, origin at the left end (node 1)', ...
    'v', 'vertical displacement and nodal force positive upward', ...
    'theta', 'rotation and nodal couple positive counterclockwise (theta = dv/dx)', ...
    'moment', 'internal bending moment positive sagging (tension in bottom fibre)', ...
    'shear', 'internal shear V(x) = sum of upward forces left of the section (dM/dx = V)');
model.meta.formatVersion = 5;

validateModel(model);
end

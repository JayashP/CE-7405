function model = addPointLoad(model, x, Fv)
%ADDPOINTLOAD Add a vertical point load at any coordinate along the beam.
%   MODEL = ADDPOINTLOAD(MODEL, X, FV) adds a vertical force FV [N] at the
%   global coordinate X [m]. FV is positive UPWARD (DECISIONS.md D-003): a
%   downward axle load of magnitude Q is entered as FV = -Q.
%   X does not have to coincide with a node. A load strictly inside an
%   element is applied through its Hermite consistent load vector
%   (EQUIVALENTPOINTLOAD); a load within 1e-9 times the beam length of a
%   node is applied at that node (LOCATEPOINTLOADS). X outside the beam
%   throws 'BridgeFE:offBeam'. Repeated loads are superposed.
%
%   Example (100 kN downward at x = 7.3 m):
%     model = addPointLoad(model, 7.3, -100e3);
%
%   See also LOCATEPOINTLOADS, EQUIVALENTPOINTLOAD, ADDNODALLOAD.

validateModel(model);
assertFiniteRealScalar(x, 'x');
assertFiniteRealScalar(Fv, 'Fv');
xn = model.nodes.x;
tol = 1e-9 * (xn(end) - xn(1));
if x < xn(1) - tol || x > xn(end) + tol
    error('BridgeFE:offBeam', 'Point load at x = %g m is outside the beam [%g, %g] m.', x, xn(1), xn(end));
end

model.loads.point(end+1, :) = [double(x), double(Fv)];
end

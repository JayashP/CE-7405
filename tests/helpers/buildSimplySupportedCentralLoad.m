function model = buildSimplySupportedCentralLoad(L, ne, EI, P)
%BUILDSIMPLYSUPPORTEDCENTRALLOAD Benchmark A model: pin at x = 0, roller at x = L, load P at midspan.
%   MODEL = BUILDSIMPLYSUPPORTEDCENTRALLOAD(L, NE, EI, P) builds a uniform
%   NE-element beam of length L [m] and flexural rigidity EI [N*m^2], with a
%   DOWNWARD force of magnitude P [N] (entered as -P, v positive up) at the
%   midspan node. NE must be even so that midspan is a node; loads inside
%   elements belong to a later milestone.

if mod(ne, 2) ~= 0
    error('BridgeFE:test:oddMesh', 'ne must be even so that midspan is a node.');
end
model = createBeamModel(generateUniformMesh(L, ne), EI);
model = addSupport(model, findNodeAtX(model, 0), 'pin');
model = addSupport(model, findNodeAtX(model, L), 'roller');
model = addNodalLoad(model, findNodeAtX(model, L/2), -P, 0);
end

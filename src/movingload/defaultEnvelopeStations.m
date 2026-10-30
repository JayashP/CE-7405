function stations = defaultEnvelopeStations(x, perElement)
%DEFAULTENVELOPESTATIONS Envelope stations: every node plus equal divisions of each element.
%   STATIONS = DEFAULTENVELOPESTATIONS(X, PERELEMENT) returns the sorted
%   column of coordinates [m] made of the node coordinates X and
%   PERELEMENT-1 equally spaced interior points of every element
%   (PERELEMENT >= 1; 1 means nodes only). Used by RUNMOVINGLOAD and the app
%   so both evaluate responses at the same points.
%
%   See also RUNMOVINGLOAD, PREPAREMOVINGLOAD.

assertIntegerScalarInRange(perElement, 'StationsPerElement', 1, Inf);
x = x(:);
Le = diff(x);
t = (1:perElement - 1) / perElement;
inner = bsxfun(@plus, x(1:end-1), bsxfun(@times, Le, t));
stations = unique([x; inner(:)]);
end

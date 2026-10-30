function m = mapCoordinatesToElements(x, xq, tol)
%MAPCOORDINATESTOELEMENTS Element and local position of coordinates, for left and right limits.
%   M = MAPCOORDINATESTOELEMENTS(X, XQ, TOL) maps each query coordinate
%   XQ(k) [m] on a beam with node coordinates X to the element and local
%   distance s [m] (from that element's left node) used to evaluate the
%   response just LEFT (x-) and just RIGHT (x+) of XQ(k):
%     - inside an element: both limits use the same element and s;
%     - at an interior node n (|XQ - X(n)| <= TOL): left = end of element
%       n-1 (s = L_e), right = start of element n (s = 0);
%     - at the first or last node only the limit inside the beam exists, so
%       both limits use the first or last element.
%   M fields (column vectors): eL, sL, eR, sR, node (node index or 0).
%   Coordinates must already lie on the beam.
%
%   See also PREPAREMOVINGLOAD, ANALYZEVEHICLEPOSITION.

x = x(:);
xq = xq(:);
nn = numel(x);
ne = nn - 1;
Le = diff(x);
n = numel(xq);
m.eL = zeros(n, 1);
m.sL = zeros(n, 1);
m.eR = zeros(n, 1);
m.sR = zeros(n, 1);
m.node = zeros(n, 1);
for k = 1:n
    [gap, node] = min(abs(x - xq(k)));
    if gap <= tol
        m.node(k) = node;
        if node == 1
            m.eL(k) = 1;   m.sL(k) = 0;
            m.eR(k) = 1;   m.sR(k) = 0;
        elseif node == nn
            m.eL(k) = ne;  m.sL(k) = Le(ne);
            m.eR(k) = ne;  m.sR(k) = Le(ne);
        else
            m.eL(k) = node - 1;  m.sL(k) = Le(node - 1);
            m.eR(k) = node;      m.sR(k) = 0;
        end
    else
        e = find(x(1:end-1) < xq(k), 1, 'last');
        m.eL(k) = e;
        m.sL(k) = xq(k) - x(e);
        m.eR(k) = e;
        m.sR(k) = m.sL(k);
    end
end
end

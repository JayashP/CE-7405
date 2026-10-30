function d = responseDiagramData(res)
%RESPONSEDIAGRAMDATA Plot-ready V, M and v along the beam for one vehicle position.
%   D = RESPONSEDIAGRAMDATA(RES) merges the station and under-axle results
%   of ANALYZEVEHICLEPOSITION into columns sorted by x. Every point appears
%   twice, first with its left limit (x-) and then with its right limit
%   (x+), so shear jumps under axles and at supports are drawn as vertical
%   steps. D fields: x [m], V [N], M [N*m], v [m].
%
%   See also ANALYZEVEHICLEPOSITION, PLOTDIAGRAM.

st = res.stations;
ap = res.axlePoints;
x = [st.x; ap.x];
rows = [x, zeros(size(x)), [st.VL; ap.VL], [st.ML; ap.ML], [st.v; ap.v]; ...
        x, ones(size(x)),  [st.VR; ap.VR], [st.MR; ap.MR], [st.v; ap.v]];
rows = sortrows(rows, [1 2]);
d.x = rows(:, 1);
d.V = rows(:, 3);
d.M = rows(:, 4);
d.v = rows(:, 5);
end

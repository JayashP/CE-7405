function exportDrawingPreviews(outDir)
%EXPORTDRAWINGPREVIEWS Write example drawing primitives and diagram data to JSON (development check).
%   EXPORTDRAWINGPREVIEWS(OUTDIR) builds a few example models with the
%   verified engine, creates their drawings with BRIDGEDRAWING and their
%   response data with RESPONSEDIAGRAMDATA, and writes them as JSON files to
%   OUTDIR. tools/preview/render_drawing_previews.py then renders the very
%   same coordinates with matplotlib, so the app's drawings can be inspected
%   without MATLAB. Not used by the app.
%
%   See also BRIDGEDRAWING, RESPONSEDIAGRAMDATA.

if ~exist(outDir, 'dir')
    mkdir(outDir);
end
th = appTheme();
EI = 2e9;
truck = createVehicle([80e3 120e3 120e3], [4.2 1.4], 'spec 3-axle example');

% 1. Benchmark A: simple span with a central point load, node numbers on
m = createBeamModel(generateUniformMesh(20, 8), EI);
m = addSupport(m, 1, 'pin');
m = addSupport(m, 9, 'roller');
m = addPointLoad(m, 10, -100e3);
writeCase(outDir, 'A_simple_span_point_load', bridgeDrawing(m, struct('ShowNumbers', true)), []);

% 2. Benchmark C: propped cantilever with a uniform load
m = createBeamModel(generateUniformMesh(10, 8), EI);
m = addSupport(m, 1, 'fixed');
m = addSupport(m, 9, 'roller');
m = addUniformLoad(m, -20e3);
writeCase(outDir, 'C_propped_cantilever_udl', bridgeDrawing(m), []);

% 3. Two spans, RCC span 2, permanent load and couple, truck at x_v = 16 m with deformed shape
[x, xs] = meshSpans([12 15], [8 10]);
m = createBeamModel(x, defineMaterial('steel', 200e9, 0.01));
m = assignMaterial(m, defineMaterial('rcc', 32e9, 0.0625), elementsBetween(m, xs(2), xs(3)));
m = addSupport(m, findNodeAtX(m, xs(1)), 'pin');
m = addSupport(m, findNodeAtX(m, xs(2)), 'roller');
m = addSupport(m, findNodeAtX(m, xs(3)), 'roller');
m = addUniformLoad(m, -10e3, elementsBetween(m, xs(1), xs(2)));
m = addNodalLoad(m, findNodeAtX(m, 6), 0, 50e3);
prep = prepareMovingLoad(m, defaultEnvelopeStations(m.nodes.x, 4));
res = analyzeVehiclePosition(prep, truck, 16, 1);
d = responseDiagramData(res);
mag = 0.8 * 0.04 * 27 / max(abs(d.v));
opts = struct('Axles', res.axles, 'Deformed', struct('x', d.x, 'y', d.v * mag), ...
    'DeformedLabel', sprintf('deformed shape x %.0f', mag));
writeCase(outDir, 'D_two_span_truck_deformed', bridgeDrawing(m, opts), d);

% 4. Truck entering a cantilever fixed at the right end (axles partly off the bridge)
m = createBeamModel(generateUniformMesh(12, 6), EI);
m = addSupport(m, 7, 'fixed');
prep = prepareMovingLoad(m, defaultEnvelopeStations(m.nodes.x, 4));
res = analyzeVehiclePosition(prep, truck, 3, 1);
writeCase(outDir, 'E_cantilever_truck_entering', bridgeDrawing(m, struct('Axles', res.axles)), responseDiagramData(res));
fprintf('wrote previews to %s (theme moment colour %s)\n', outDir, mat2str(th.moment, 3));
end

function writeCase(outDir, name, prims, d)
s.name = name;
s.prims = prims;
[xl, yl] = drawingLimits(prims);
s.limits = struct('xl', xl, 'yl', yl);   % the limits RENDERDRAWING will use
if ~isempty(d)
    s.diagram = d;
end
fid = fopen(fullfile(outDir, [name '.json']), 'w');
fprintf(fid, '%s', jsonencode(s));
fclose(fid);
end

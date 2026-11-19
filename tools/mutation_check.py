"""Mutation check: verify that the M1 test suite detects deliberately injected solver bugs."""
import shutil, subprocess, sys, pathlib, re
# Usage: python3 -I tools/mutation_check.py <repo_root> <empty_scratch_dir> [name_prefix [test_glob]]
# Copies the repo once per mutation, injects one deliberate bug, runs the suite in
# GNU Octave and reports which tests detect it. Never modifies <repo_root>.
repo = pathlib.Path(sys.argv[1]).resolve()
work = pathlib.Path(sys.argv[2]).resolve()
mutations = [
  ('k22 coefficient 4->3', 'src/elements/beamElementStiffness.m', '6*Le,   4*Le^2,  -6*Le,   2*Le^2;', '6*Le,   3*Le^2,  -6*Le,   2*Le^2;'),
  ('rotation-coupling sign flipped (k12,k21)', 'src/elements/beamElementStiffness.m', "ke = (EI / Le^3) * [ 12,     6*Le,    -12,     6*Le;\n                     6*Le,", "ke = (EI / Le^3) * [ 12,    -6*Le,    -12,     6*Le;\n                    -6*Le,"),
  ('DOF map v/theta swapped', 'src/model/elementDofs.m', 'dofMap = [2*i - 1, 2*i, 2*j - 1, 2*j];', 'dofMap = [2*i, 2*i - 1, 2*j, 2*j - 1];'),
  ('end-moment sign at node i', 'src/solver/recoverElementForces.m', 'ef.moment = [-endActions(:, 2), endActions(:, 4)];', 'ef.moment = [endActions(:, 2), endActions(:, 4)];'),
  ('reactions ignore loads at restrained DOFs', 'src/solver/recoverReactions.m', 'R(r) = full(K(r, :) * U(:) - F(r));', 'R(r) = full(K(r, :) * U(:));'),
  ('no under-restraint check', 'src/solver/partitionDofs.m', "if isempty(vRestrainedNodes)", "if false"),
  ('assembly uses wrong element length (x_j only)', 'src/model/assembleGlobalK.m', 'Le = x(conn(e, 2)) - x(conn(e, 1));', 'Le = 1.0;'),
  # M2 (uniform member loads, indeterminate beams)
  ('M2: member-load term f_e0 not subtracted in recovery', 'src/solver/recoverElementForces.m', "* U(dofMap(e, :))).' - f0(e, :);", "* U(dofMap(e, :))).';"),
  ('M2: consistent-load end moments swapped in sign', 'src/loads/equivalentDistributedLoad.m', 'fe0 = w * [Le/2; Le^2/12; Le/2; -Le^2/12];', 'fe0 = w * [Le/2; -Le^2/12; Le/2; Le^2/12];'),
  ('M2: element loads left out of the global load vector', 'src/solver/solveStaticModel.m', 'F = assembleLoadVector(model);', 'F = assembleNodalLoadVector(model);'),
  ('M2: parabolic moment term sign flipped in sampling', 'src/postprocess/sampleInternalForces.m', 'M = Mi + Vi * tRows + w(e) * tRows.^2 / 2;', 'M = Mi + Vi * tRows - w(e) * tRows.^2 / 2;'),
  ('M2: element load uses a unit element length', 'src/loads/elementLoadVectors.m', 'f0(e, :) = equivalentDistributedLoad(w(e), Le).\';', 'f0(e, :) = equivalentDistributedLoad(w(e), 1).\';'),
  # M3 (point loads inside elements, deflection between nodes)
  ('M3: N2 shape-function coefficient wrong', 'src/elements/beamShapeFunctions.m', 'Le * (r - 2*r.^2 + r.^3)', 'Le * (r - r.^2 + r.^3)'),
  ('M3: point-load shear jump sign flipped in sampling', 'src/postprocess/sampleInternalForces.m', 'V = V + PK(j) * acts;', 'V = V - PK(j) * acts;'),
  ('M3: UDL particular solution omitted in deflection', 'src/postprocess/evaluateDeflection.m', 'vk = vk + w(e) * s^2 * (Le - s)^2 / (24 * EI(e));', 'vk = vk;'),
  ('M3: point-load particular solution omitted (s <= a)', 'src/postprocess/evaluateDeflection.m', 'vk = vk + loc.P(j) * b^2 * s^2 * (3*a*Le - (3*a + b)*s) / (6 * EI(e) * Le^3);', 'vk = vk;'),
  ('M3: point load located in the wrong element', 'src/loads/locatePointLoads.m', "e = find(x(1:end-1) < loc.x(k), 1, 'last');", "e = find(x(1:end-1) < loc.x(k), 1, 'first');"),
  ('M3: point loads at nodes dropped from F', 'src/loads/assembleLoadVector.m', 'F(2*n - 1) = F(2*n - 1) + loc.P(k);', 'F(2*n - 1) = F(2*n - 1);'),
  # M4 (moving vehicle, envelopes, critical positions)
  ('M4: only one triangular solve with the Cholesky factor', 'src/movingload/analyzeVehiclePosition.m', "U(prep.freeDofs) = prep.Rc \\ (prep.Rc' \\ F(prep.freeDofs));", "U(prep.freeDofs) = prep.Rc \\ F(prep.freeDofs);"),
  ('M4: axles off the bridge are applied at the ends', 'src/movingload/analyzeVehiclePosition.m', 'onBridge = xa >= x(1) - tol & xa <= x(end) + tol;', 'onBridge = true(size(xa));'),
  ('M4: right-limit shear ignores a load at the point', 'src/movingload/analyzeVehiclePosition.m', 'acts = inElement & s >= loads.a(k) - tol;', 'acts = inElement & s > loads.a(k) + tol;'),
  ('M4: rear axles placed ahead of the front axle', 'src/loads/vehicleAxlePositions.m', 'x = xv - direction * offsets;', 'x = xv + direction * offsets;'),
  ('M4: envelope minimum tracks maxima', 'src/movingload/runMovingLoad.m', 'better = candidate < current;', 'better = candidate > current;'),
  ('M4: step refinement disabled', 'src/movingload/runMovingLoad.m', 'if opts.Refine\n', 'if false\n'),
  ('M4: axle load vector mirrored inside the element', 'src/movingload/analyzeVehiclePosition.m', 'fe = equivalentPointLoad(POn(k), a, Le(e));', 'fe = equivalentPointLoad(POn(k), Le(e) - a, Le(e));'),
  ('M4: crossing stops when the front axle leaves', 'src/loads/generateVehiclePositions.m', 'xEnd = x(end) + vehicleLength;', 'xEnd = x(end);'),
  # M5 (steel / RCC material input)
  ('M5: material EI stored as E instead of E*I', 'src/materials/defineMaterial.m', "'EI', double(E) * double(I),", "'EI', double(E),"),
  ('M5: assignMaterial does not update EI', 'src/materials/assignMaterial.m', 'model.elements.EI(elements) = material.EI;', ''),
  ('M5: EI-vs-material consistency check disabled', 'src/model/validateModel.m', 'if abs(EI(e) - mat.EI) > 1e-12 * mat.EI', 'if false'),
  ('M5: createBeamModel takes E as EI', 'src/model/createBeamModel.m', '    EI = EI.EI;', '    EI = EI.E;'),
  ('M5: unit-sanity warning disabled', 'src/materials/defineMaterial.m', 'if E < range(1) || E > range(2)', 'if false'),
  # M6 (GUI helpers and drawing geometry; the app itself is checked by tests/gui/checkBridgeConditionApp)
  ('M6: GPa input converted with 1e6 instead of 1e9', 'src/gui/buildModelFromInputs.m', 'in.E_GPa * 1e9', 'in.E_GPa * 1e6'),
  ('M6: uniform load entered upward', 'src/gui/buildModelFromInputs.m', 'model = addUniformLoad(model, -q * 1e3);', 'model = addUniformLoad(model, q * 1e3);'),
  ('M6: axle loads in kN not converted to N', 'src/gui/vehicleFromInputs.m', 'vehicle = createVehicle(loads * 1e3, spacings, name);', 'vehicle = createVehicle(loads, spacings, name);'),
  ('M6: right limit listed before left limit in diagram data', 'src/gui/responseDiagramData.m', 'rows = sortrows(rows, [1 2]);', 'rows = sortrows(rows, [1 -2]);'),
  ('M6: fixed-wall hatching drawn inside the beam', 'src/visualization/supportSymbolGeometry.m', "        if strcmpi(side, 'right')\n            s = -1;", "        if strcmpi(side, 'left')\n            s = -1;"),
  ('M6: no label room in drawing limits', 'src/visualization/drawingLimits.m', 'pad = 0.03 * dx;', 'pad = 0;'),
  ('M6: critical table shows N*m instead of kN*m', 'src/gui/criticalTableData.m', "scales = struct('M', 1e-3, 'V', 1e-3, 'v', 1e3);", "scales = struct('M', 1, 'V', 1e-3, 'v', 1e3);"),
  # M7 (Stage 2: prescribed stiffness loss)
  ('M7: effectiveEI ignores the stiffness factor', 'src/damage/effectiveEI.m', 'EIeff = model.elements.EI .* model.elements.stiffnessFactor;', 'EIeff = model.elements.EI;'),
  ('M7: damage factor 1/(1+d) instead of 1-d', 'src/damage/applyStiffnessDamage.m', 'model.elements.stiffnessFactor(elements) = 1 - d(:);', 'model.elements.stiffnessFactor(elements) = 1 ./ (1 + d(:));'),
  ('M7: moving-load fast path uses the material EI', 'src/movingload/prepareMovingLoad.m', 'prep.EI = effectiveEI(model);', 'prep.EI = model.elements.EI;'),
  ('M7: force recovery uses the material EI', 'src/solver/recoverElementForces.m', 'EI = effectiveEI(model);', 'EI = model.elements.EI;'),
  ('M7: zero healthy reference not excluded from percentages', 'src/damage/relativeChange.m', 'pct(abs(healthy) <= 1e-9 * scale) = NaN;', ''),
  # M7b (Damage tab helpers)
  ('M7b: damage tab passes the remaining fraction instead of the loss', 'src/gui/damageModelFromInputs.m', 'applyStiffnessDamage(model, elements, dPercent / 100);', 'applyStiffnessDamage(model, elements, 1 - dPercent / 100);'),
  ('M7b: damage summary names the wrong last element', 'src/gui/damageModelFromInputs.m', '    elements(1), elements(end), xFrom', '    elements(1), elements(1), xFrom'),
  ('M7b: deflection shown in m instead of mm', 'src/gui/quantityDisplay.m', "'unit', 'mm', 'scale', 1e3", "'unit', 'mm', 'scale', 1"),
  ('M7b: comparison percentage loses its sign', 'src/gui/damageComparisonTableData.m', "    s = formatNumber(p, 2, true);", "    s = formatNumber(abs(p), 2, true);"),
  ('M7b: sensitivity table not in rank order', 'src/gui/sensitivityTableData.m', '    g = s.rank(k);', '    g = k;'),
  ('M7b: sensitivity labels mapped to the wrong codes', 'src/gui/sensitivityQuantityCode.m', "codes = {'vmin', 'Mmax',", "codes = {'Mmax', 'vmin',"),
  ('M7b: drawing merges runs with different factors', 'src/visualization/bridgeDrawing.m', 'while last < numel(f) && f(last + 1) == f(e)', 'while last < numel(f) && f(last + 1) < 1'),
  # M7c (Damage-tab display)
  ('M7c: round-off printed as a negative zero', 'src/gui/formatNumber.m', 'if r == 0', 'if false'),
  ('M7c: degree of indeterminacy off by one', 'src/gui/damageComparisonSummary.m', 'degree = numel(restrained) - 2;', 'degree = numel(restrained) - 1;'),
  ('M7c: findings call a larger magnitude smaller', 'src/gui/damageComparisonSummary.m', 'if abs(c.damaged) > abs(c.healthy)', 'if abs(c.damaged) < abs(c.healthy)'),
  # S3 (Stage 3 inverse search)
  ('S3: healthy candidate left out of the search', 'src/inverse/identifySingleDamage.m', 'evJ = J0;', 'evJ = Inf;'),
  ('S3: no 1 % refinement by default', 'src/inverse/identifySingleDamage.m', "'RefineStep', 0.01,", "'RefineStep', 0,"),
  ('S3: missing readings not excluded', 'src/inverse/identifySingleDamage.m', 'known = ~isnan(uObs);', 'known = true(size(uObs));'),
  ('S3: permanent-load deflection not subtracted', 'src/inverse/predictSensorDeflections.m', 'u(:, p) = res.stations.v(:) - base.stations.v(:);', 'u(:, p) = res.stations.v(:);'),
  ('S3: competing candidates ignore the ambiguity ratio', 'src/inverse/identifySingleDamage.m', 'threshold = max(opts.AmbiguityRatio * best.J, floorJ);', 'threshold = max(best.J, floorJ);'),
  ('S3: search-limit flag never set', 'src/inverse/identifySingleDamage.m', 'best.d >= max(levels) - 1e-12', 'best.d > max(levels)'),
  ('S3: noise not proportional to each reading', 'src/inverse/addMeasurementNoise.m', 'uNoisy = u .* (1 + level * z);', 'uNoisy = u + level * mean(abs(u(known))) * z;'),
  # S3b (noise-based region, fit check, candidate region size)
  ('S3b: region uses 1 instead of 2 degrees of freedom', 'src/inverse/identifySingleDamage.m', 'delta = chiSquareQuantile(opts.Confidence, 2);', 'delta = chiSquareQuantile(opts.Confidence, 1);'),
  ('S3b: readings not weighted by their own sigma', 'src/inverse/identifySingleDamage.m', 'S = sum((r ./ sigma(known)).^2);', 'S = sum(r.^2) / mean(sigma(known).^2);'),
  ('S3b: best candidate by RMSE despite a stated noise level', 'src/inverse/identifySingleDamage.m', 'if likelihood\n    evF = evS;', 'if likelihood\n    evF = evJ;'),
  ('S3b: only the 3 best groups refined with a stated noise level', 'src/inverse/identifySingleDamage.m', 'refine(:) = true;', 'refine(order(1:min(3, nG))) = true;'),
  ('S3b: sigma from the noisy readings', 'src/inverse/identifySingleDamage.m', 'sigma = sqrt((p * abs(uHealthy)).^2 + s^2);', 'sigma = sqrt((p * abs(uObs)).^2 + s^2);'),
  ('S3b: no structure at the parabola vertex', 'src/inverse/identifySingleDamage.m', 'if ~isnan(dv) && all(abs(evD(own) - dv) > 1e-9)', 'if false'),
  ('S3b: parabola vertex allowed at d <= 0 or outside the neighbours', 'src/inverse/identifySingleDamage.m', 'if vertex > max(dl, 0) && vertex < dr', 'if true'),
  ('S3b: region reaching the 60 % limit not flagged', 'src/inverse/identifySingleDamage.m', 'result.regionAtSearchLimit = any(evGroup(insidePoint) > 0 & evD(insidePoint) >= max(levels) - 1e-12);', 'result.regionAtSearchLimit = false;'),
  ('S3b: no RCC caveat', 'src/inverse/identifySingleDamage.m', "any(strcmpi({model.materials(unique(ids)).type}, 'rcc'))", 'false'),
  ('S3b: m - 2 degrees of freedom when the healthy model fits best', 'src/inverse/identifySingleDamage.m', '        dof = m;                               % the healthy model has no fitted unknowns', '        dof = m - 2;'),
  ('S3b: seed used directly as the generator state', 'src/inverse/deterministicNormal.m', 'state = hashSeed32(seed);', 'state = mod(double(seed), m);'),
  ('S3b: fit check without subtracting the 2 fitted unknowns', 'src/inverse/identifySingleDamage.m', 'dof = m - 2;', 'dof = m;'),
  ('S3b: chi-square quantile from the wrong tail', 'src/inverse/chiSquareQuantile.m', '    if cdf(mid) < p', '    if cdf(mid) < 1 - p'),
  ('S3b: short last region kept separate up to the full length', 'src/inverse/candidateGroups.m', 'if acc < 0.5 * regionLength - tol', 'if acc < regionLength - tol'),
  # M8 (Identification tab helpers)
  ('M8: synthetic noise in % passed as a fraction', 'src/gui/syntheticObservations.m', 'addMeasurementNoise(u, noisePercent / 100, seed)', 'addMeasurementNoise(u, noisePercent, seed)'),
  ('M8: absolute noise mm converted with 1/100', 'src/gui/identificationOptions.m', "{'NoiseAbsolute', noiseAbsoluteMm / 1000}", "{'NoiseAbsolute', noiseAbsoluteMm / 100}"),
  ('M8: every candidate shown as inside the region', 'src/gui/fitProfileData.m', "p.inRegion = ismember((1:nG)', [result.competing.group]');", 'p.inRegion = true(nG, 1);'),
  ('M8: healthy row missing from the candidate table', 'src/gui/identificationTableData.m', 'if result.healthyCompetes || ~result.damageDetected', 'if false'),
  ('M8: healthy-best region not reported', 'src/gui/identificationSummary.m', '    if ~isempty(result.competing)\n        dMax', '    if false\n        dMax'),
  ('M8: sensors on a support kept', 'src/gui/identificationDefaults.m', "sensorX = sensorX(max(abs(uH), [], 2)' > small);", 'sensorX = sensorX;'),
  ('M8: truth comparison answers the opposite', 'src/gui/identificationSummary.m', 'yesNo(inside), yesNo(covers)', 'yesNo(~inside), yesNo(covers)'),
  ('M8: positions with all-zero readings kept', 'src/gui/identificationDefaults.m', 'positions = positions(max(abs(uH), [], 1) > small);', 'positions = positions;'),
  ('M8: -x travel positions not mirrored', 'src/gui/identificationDefaults.m', '    positions = x(end) - offset;', '    positions = x(1) + offset;'),
  ('M8: region bands drawn over the beam', 'src/visualization/bridgeDrawing.m', 'prims = [band, prims];', 'prims = [prims, band];'),
  ('M8: readings mm converted with 1/100', 'src/gui/readingsFromTable.m', 'uObs = double(data) / 1000;', 'uObs = double(data) / 100;'),
  # M9b (table inputs, vehicle presets, drawing labels and units)
  ('M9b: support letters off by one after Z', 'src/gui/supportLetters.m', 'm = (m - 1 - r) / 26;', 'm = floor(m / 26);'),
  ('M9b: Free mapped to a fixed support', 'src/gui/supportTypeList.m', "engineTypes = {'pin', 'roller', 'fixed', 'none'};", "engineTypes = {'pin', 'roller', 'fixed', 'fixed'};"),
  ('M9b: support labels matched case-sensitively', 'src/gui/buildModelFromTables.m', 'j = find(strcmpi(strtrim(t), labels), 1);', 'j = find(strcmp(strtrim(t), labels), 1);'),
  ('M9b: US modulus converted as GPa', 'src/gui/buildModelFromTables.m', 'E * U.modulus.toSI', 'E * 1e9'),
  ('M9b: US inertia not converted', 'src/gui/buildModelFromTables.m', 'I * U.inertia.toSI', 'I'),
  ('M9b: US distributed load converted as kN/m', 'src/gui/buildModelFromTables.m', 'model = addUniformLoad(model, -q * U.distributed.toSI);', 'model = addUniformLoad(model, -q * 1e3);'),
  ('M9b: integer-class modulus not read as double', 'src/gui/buildModelFromTables.m', 'E = double(in.E);', 'E = in.E;'),
  ('M9b: span lengths not converted to m', 'src/gui/buildModelFromTables.m', '[x, xs] = meshSpans(spans * U.length.toSI, elements);', '[x, xs] = meshSpans(spans, elements);'),
  ('M9b: per-span element counts replaced by the first', 'src/gui/buildModelFromTables.m', '[x, xs] = meshSpans(spans * U.length.toSI, elements);', '[x, xs] = meshSpans(spans * U.length.toSI, elements(1));'),
  ('M9b: summary support x are the span lengths', 'src/gui/buildModelFromTables.m', 'xDisplay = [0, cumsum(spans)];', 'xDisplay = [0, spans];'),
  ('M9b: summary EI in kN whatever the units', 'src/gui/buildModelFromTables.m', 'EIdisplay = material.EI / (U.force.toSI * U.length.toSI^2);', 'EIdisplay = material.EI / (1e3 * U.length.toSI^2);'),
  ('M9b: span-length row check skipped', 'src/gui/buildModelFromTables.m', 'if ~(spans(k) > 0)', 'if false'),
  ('M9b: element count upper limit not checked', 'src/gui/buildModelFromTables.m', '&& elements(k) <= 2000)', ')'),
  ('M9b: vehicle table loads converted as kN', 'src/gui/vehicleFromTable.m', 'vehicle = createVehicle(loads * U.force.toSI, gaps * U.length.toSI, name);', 'vehicle = createVehicle(loads * 1e3, gaps * U.length.toSI, name);'),
  ('M9b: vehicle table spacings not converted', 'src/gui/vehicleFromTable.m', 'vehicle = createVehicle(loads * U.force.toSI, gaps * U.length.toSI, name);', 'vehicle = createVehicle(loads * U.force.toSI, gaps, name);'),
  ('M9b: spacing error names the wrong axle row', 'src/gui/vehicleFromTable.m', "must be a positive number (%s).', k + 1, k, U.length.unit);", "must be a positive number (%s).', k, k - 1, U.length.unit);"),
  ('M9b: HL-93 preset read as SI values', 'src/gui/vehiclePresets.m', '[8 32 32], [14 14], US, U', '[8 32 32], [14 14], SI, U'),
  ('M9b: preset conversion factor inverted', 'src/gui/vehiclePresets.m', 'loads = loads * defined.force.toSI / U.force.toSI;', 'loads = loads * U.force.toSI / defined.force.toSI;'),
  ('M9b: preset spacings not converted', 'src/gui/vehiclePresets.m', 'spacings = spacings * defined.length.toSI / U.length.toSI;', 'spacings = spacings;'),
  ('M9b: drawing ignores the Units option', 'src/visualization/bridgeDrawing.m', "U = optionOr(opts, 'Units', unitSystem('SI'));", "U = unitSystem('SI');"),
  ('M9b: point-load label always in kN', 'src/visualization/bridgeDrawing.m', "label = sprintf('%g %s', abs(P) / force.toSI, force.unit);", "label = sprintf('%g kN', abs(P) / 1e3);"),
  ('M9b: couple label always in kN*m', 'src/visualization/bridgeDrawing.m', "sprintf('%g %s (%s)', abs(Mz) / moment.toSI, moment.unit, sense)", "sprintf('%g kN*m (%s)', abs(Mz) / 1e3, sense)"),
  ('M9b: close axles never share a label', 'src/visualization/bridgeDrawing.m', '>= 0.06 * L', '>= 0'),
  ('M9b: axle label threshold 8 % of L', 'src/visualization/bridgeDrawing.m', '>= 0.06 * L', '>= 0.08 * L'),
  ('M9b: axle label threshold 3 % of L', 'src/visualization/bridgeDrawing.m', '>= 0.06 * L', '>= 0.03 * L'),
  ('M9b: merged label always lists loads with +', 'src/visualization/bridgeDrawing.m', 'elseif all(strcmp(values, values{1}))', 'elseif false'),
  ('M9b: axle groups formed in table order, not left to right', 'src/visualization/bridgeDrawing.m', '[~, order] = sort(ax.x(on));', 'order = 1:numel(on);'),
  ('M9b: off-bridge axles lose their labels', 'src/visualization/bridgeDrawing.m', 'if ~ax.onBridge(k)', 'if false'),
  ('M9b: load label back at mid-length', 'src/visualization/bridgeDrawing.m', "    prims(end+1) = drawingPrimitive('text', xa, level + sgn*0.15*h, th.load, ...", "    prims(end+1) = drawingPrimitive('text', (xa + xb)/2, level + sgn*0.15*h, th.load, ..."),
  ('M9b: load label centred', 'src/visualization/bridgeDrawing.m', "'hAlign', 'left', 'vAlign', vertical(sgn), 'fontSize', 9);", "'vAlign', vertical(sgn), 'fontSize', 9);"),
  ('M9b: end labels drawn inside the support symbols', 'src/visualization/bridgeDrawing.m', "prims(end+1) = drawingPrimitive('text', ends.x(k), -1.55*h,", "prims(end+1) = drawingPrimitive('text', ends.x(k), -0.55*h,"),
  ('M9b: end labels not bold', 'src/visualization/bridgeDrawing.m', "'vAlign', 'top', 'fontSize', 10, 'fontWeight', 'bold');", "'vAlign', 'top', 'fontSize', 10);"),
  ('M9b: node numbers drawn under the end labels', 'src/visualization/bridgeDrawing.m', "for n = find(~labelled).'", 'for n = 1:nn'),
  ('M9b: Inf span length not rejected with its row', 'src/gui/buildModelFromTables.m', '    v(~isfinite(v)) = NaN;\n', ''),
  ('M9b: Inf axle load not rejected with its row', 'src/gui/vehicleFromTable.m', '    v(~isfinite(v)) = NaN;\n', ''),
  ('M9b: off-bridge axle labels always in kN', 'src/visualization/bridgeDrawing.m', 'axleLabel(ax.P(k), U.force)', "axleLabel(ax.P(k), unitSystem('SI').force)"),
]
only = sys.argv[3] if len(sys.argv) > 3 else ''   # optional name prefix, e.g. 'M7b:'
mutations = [m for m in mutations if m[0].startswith(only)]
import os
shard = os.environ.get('MUTANT_SHARD', '')   # e.g. '0/3': run every 3rd mutant starting at 0 (parallel runs)
if shard:
    k, n_shards = map(int, shard.split('/'))
    mutations = mutations[k::n_shards]
for name, rel, old, new in mutations:
    d = work / re.sub(r'[^a-z0-9]+', '_', name.lower())
    if d.exists(): shutil.rmtree(d)
    shutil.copytree(repo, d, ignore=shutil.ignore_patterns('.git', 'results'))
    if len(sys.argv) > 4:   # optional test-file glob: keep only matching tests (code under test used nowhere else)
        for tf in (d / 'tests').glob('test*.m'):
            if not tf.match(sys.argv[4]): tf.unlink()
    f = d / rel
    text = f.read_text()
    assert text.count(old) == 1, f'mutation target not found exactly once: {name}'
    f.write_text(text.replace(old, new))
    p = subprocess.run(['timeout', '1200', 'octave-cli', '--no-gui', '--norc', '--eval', 'runAllTests'], cwd=d, capture_output=True, text=True)
    out = p.stdout + p.stderr
    total = re.findall(r'Total: (\d+) passed, (\d+) failed', out)
    failed_tests = re.findall(r'^\s+FAIL\s+(\S+ / .*)$', out, re.M)
    print(f'MUTATION: {name}\n  exit={p.returncode} summary={total}\n  detected by: ' + ('; '.join(failed_tests[:6]) + (' ...' if len(failed_tests) > 6 else '') if failed_tests else '  NOT DETECTED'))

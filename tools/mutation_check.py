"""Mutation check: verify that the M1 test suite detects deliberately injected solver bugs."""
import shutil, subprocess, sys, pathlib, re
# Usage: python3 -I tools/mutation_check.py <repo_root> <empty_scratch_dir> [name_prefix]
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
  ('M7b: comparison percentage loses its sign', 'src/gui/damageComparisonTableData.m', "    s = sprintf('%+.2f', p);", "    s = sprintf('%+.2f', abs(p));"),
  ('M7b: sensitivity table not in rank order', 'src/gui/sensitivityTableData.m', '    g = s.rank(k);', '    g = k;'),
  ('M7b: sensitivity labels mapped to the wrong codes', 'src/gui/sensitivityQuantityCode.m', "codes = {'vmin', 'Mmax',", "codes = {'Mmax', 'vmin',"),
  ('M7b: drawing merges runs with different factors', 'src/visualization/bridgeDrawing.m', 'while last < numel(f) && f(last + 1) == f(e)', 'while last < numel(f) && f(last + 1) < 1'),
]
only = sys.argv[3] if len(sys.argv) > 3 else ''   # optional name prefix, e.g. 'M7b:'
mutations = [m for m in mutations if m[0].startswith(only)]
for name, rel, old, new in mutations:
    d = work / re.sub(r'[^a-z0-9]+', '_', name.lower())
    if d.exists(): shutil.rmtree(d)
    shutil.copytree(repo, d, ignore=shutil.ignore_patterns('.git', 'results'))
    f = d / rel
    text = f.read_text()
    assert text.count(old) == 1, f'mutation target not found exactly once: {name}'
    f.write_text(text.replace(old, new))
    p = subprocess.run(['timeout', '300', 'octave-cli', '--no-gui', '--norc', '--eval', 'runAllTests'], cwd=d, capture_output=True, text=True)
    out = p.stdout + p.stderr
    total = re.findall(r'Total: (\d+) passed, (\d+) failed', out)
    failed_tests = re.findall(r'^\s+FAIL\s+(\S+ / .*)$', out, re.M)
    print(f'MUTATION: {name}\n  exit={p.returncode} summary={total}\n  detected by: ' + ('; '.join(failed_tests[:6]) + (' ...' if len(failed_tests) > 6 else '') if failed_tests else '  NOT DETECTED'))

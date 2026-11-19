%TESTUNITSDISPLAY Results in the chosen display units (M9 part A): SI as before, US customary converted.
%   Script-based test file (see runAllTests). Every display helper of the
%   app takes an optional last argument U = UNITSYSTEM('SI' or 'US'). Checked
%   here: the unit factors against independent constants (international
%   foot 0.3048 m and inch 0.0254 m, pound-force 4.4482216152605 N); with
%   U = SI every output is ISEQUAL to the call without U (the output before
%   M9); with U = US every number shown equals the SI quantity converted
%   (read back with str2double, within the rounding of the shown decimals)
%   and every header, label and summary line names US units. Minimum
%   reactions are also checked on a two-span beam whose end supports lift
%   off, since on the propped cantilever they are all 0 and 0 reads the same
%   in every unit. The plot
%   functions draw into RecordingAxes (tests/helpers), which records the
%   drawn data and texts without a window.
SI = unitSystem('SI');
US = unitSystem('US');
ft = 0.3048;                          % m, international foot (exact)
inch = 0.0254;                        % m, international inch (exact)
kip = 1000 * 4.4482216152605;         % N, 1000 lbf (avoirdupois pound x 9.80665 m/s^2)
truck = createVehicle([80e3 120e3 120e3], [4.2 1.4]);         % spec 3-axle example
propped = createBeamModel(generateUniformMesh(20, 8), 2e9);   % 2.5 m elements, fixed at x = 0
propped = addSupport(propped, 1, 'fixed');
propped = addSupport(propped, 9, 'roller');
% two spans 12 m + 15 m, pin / roller / roller: the end supports lift off (minimum reactions < 0), which the
% propped cantilever never does (all its minimum reactions are 0, and 0 reads the same in any unit)
[xTwo, xsTwo] = meshSpans([12 15], [8 10]);
twoSpan = createBeamModel(xTwo, 2e9);
twoSpan = addSupport(twoSpan, findNodeAtX(twoSpan, xsTwo(1)), 'pin');
twoSpan = addSupport(twoSpan, findNodeAtX(twoSpan, xsTwo(2)), 'roller');
twoSpan = addSupport(twoSpan, findNodeAtX(twoSpan, xsTwo(3)), 'roller');
% text shown with DECIMALS fixed decimals (FORMATNUMBER) or with %g (6 significant digits) reads VALUE
showsFixed = @(text, value, decimals) abs(str2double(text) - value) <= 0.5 * 10^(-decimals) + 1e-9 * max(1, abs(value));
showsG = @(text, value) abs(str2double(text) - value) <= 5e-6 * abs(value) + 1e-12;

%% Unit factors equal independent constants, and SI is the default
assert(isequal(unitSystem(), SI) && isequal(unitSystem(''), SI), 'SI is the default unit system');
assert(strcmp(SI.length.unit, 'm') && strcmp(SI.deflection.unit, 'mm') && strcmp(SI.force.unit, 'kN') ...
    && strcmp(SI.moment.unit, 'kN*m') && strcmp(SI.distributed.unit, 'kN/m') && strcmp(SI.modulus.unit, 'GPa') ...
    && strcmp(SI.inertia.unit, 'm^4'), 'SI unit texts');
assert(isequal([SI.length.toSI, SI.deflection.toSI, SI.force.toSI, SI.moment.toSI, SI.distributed.toSI, ...
    SI.modulus.toSI, SI.inertia.toSI], [1, 1e-3, 1e3, 1e3, 1e3, 1e9, 1]), 'SI factors');
assert(strcmp(US.length.unit, 'ft') && strcmp(US.deflection.unit, 'in') && strcmp(US.force.unit, 'kip') ...
    && strcmp(US.moment.unit, 'kip*ft') && strcmp(US.distributed.unit, 'kip/ft') && strcmp(US.modulus.unit, 'ksi') ...
    && strcmp(US.inertia.unit, 'in^4'), 'US unit texts');
reportComparisons('US customary unit factors to SI (NIST SP 811)', [ ...
    compareToReference('1 ft [m]', US.length.toSI, ft, 1e-12), ...
    compareToReference('1 in [m]', US.deflection.toSI, inch, 1e-12), ...
    compareToReference('1 kip [N]', US.force.toSI, kip, 1e-12), ...
    compareToReference('1 kip*ft [N*m]', US.moment.toSI, kip * ft, 1e-12), ...
    compareToReference('1 kip/ft [N/m]', US.distributed.toSI, kip / ft, 1e-12), ...
    compareToReference('1 ksi [Pa]', US.modulus.toSI, kip / inch^2, 1e-12), ...
    compareToReference('1 in^4 [m^4]', US.inertia.toSI, inch^4, 1e-12), ...
    compareToReference('1 ksi [MPa], published 6.894757', US.modulus.toSI / 1e6, 6.894757, 1e-5)]);
assertThrows(@() unitSystem('imperial'), 'BridgeFE:invalidInput');

%% quantityDisplay: SI as before, US in kip*ft, kip and in
codes = {'M', 'V', 'v', 'R', 'Mmax', 'Vmin', 'vmin', 'Rmax'};
for k = 1:numel(codes)
    assert(isequal(quantityDisplay(codes{k}, SI), quantityDisplay(codes{k})), 'SI = call without U for %s', codes{k});
end
assert(isequal(quantityDisplay('M'), struct('label', 'Moment M', 'unit', 'kN*m', 'scale', 1e-3)) ...
    && isequal(quantityDisplay('V'), struct('label', 'Shear V', 'unit', 'kN', 'scale', 1e-3)) ...
    && isequal(quantityDisplay('v'), struct('label', 'Deflection v', 'unit', 'mm', 'scale', 1e3)) ...
    && isequal(quantityDisplay('R'), struct('label', 'Reaction R', 'unit', 'kN', 'scale', 1e-3)), 'SI values as before M9');
units = {'kip*ft', 'kip', 'in', 'kip'};
factors = [kip * ft, kip, inch, kip];
for k = 1:4
    q0 = quantityDisplay(codes{k});
    q = quantityDisplay(codes{k}, US);
    assert(strcmp(q.label, q0.label) && strcmp(q.unit, units{k}) ...
        && abs(q.scale * factors(k) - 1) < 1e-14, 'US display of %s', codes{k});
end
assertThrows(@() quantityDisplay('x', US), 'BridgeFE:invalidInput');
fprintf('  PASS SI = before M9; US: M in kip*ft, V and R in kip, v in in (scale = 1 / factor)\n');

%% Critical-position table: values, x, x_v and axle positions in US units
ml = runMovingLoad(propped, truck, 'Step', 0.5);
[d0, c0] = criticalTableData(ml);
[dSI, cSI] = criticalTableData(ml, SI);
assert(isequal(dSI, d0) && isequal(cSI, c0), 'SI = call without U');
assert(isequal(c0, {'Quantity', 'Extreme', 'Value', 'x [m]', 'x_v [m]', 'Axles on bridge [m]', 'Coarse value'}), ...
    'SI headers as before M9');
[d, c] = criticalTableData(ml, US);
assert(isequal(c, {'Quantity', 'Extreme', 'Value', 'x [ft]', 'x_v [ft]', 'Axles on bridge [ft]', 'Coarse value'}), ...
    'US headers');
factor = struct('M', kip * ft, 'V', kip, 'v', inch);
label = struct('M', 'Moment M [kip*ft]', 'V', 'Shear V [kip]', 'v', 'Deflection v [in]');
for k = 1:numel(ml.critical)
    cr = ml.critical(k);
    f = factor.(cr.quantity);
    assert(strcmp(d{k, 1}, label.(cr.quantity)) && strcmp(d{k, 2}, cr.extreme), 'row %d: quantity in US units', k);
    assert(showsFixed(d{k, 3}, cr.value / f, 3) && showsFixed(d{k, 7}, cr.coarseValue / f, 3), 'row %d: values', k);
    assert(showsFixed(d{k, 4}, cr.x / ft, 3) && showsFixed(d{k, 5}, cr.xv / ft, 3), 'row %d: x and x_v in ft', k);
    if isempty(cr.axleX)
        assert(strcmp(d{k, 6}, '(none)'), 'row %d: no axle on the bridge', k);
    else
        axles = str2double(regexp(d{k, 6}, ', ', 'split'));
        assert(numel(axles) == numel(cr.axleX) && all(abs(axles(:) - cr.axleX(:) / ft) <= 0.005 + 1e-9), ...
            'row %d: axles in ft', k);
    end
end
fprintf('  US row 1: %s %s = %s at x = %s ft (SI: %s)\n', d{1, 1}, d{1, 2}, d{1, 3}, d{1, 4}, d0{1, 3});
fprintf('  PASS SI table unchanged; %d US rows = SI quantities / factor, within the 3 decimals shown\n', size(d, 1));

%% Reaction tables: forces in kip, couples in kip*ft, coordinates in ft
ml = runMovingLoad(propped, truck, 'Step', 0.5);
x = propped.nodes.x;
[r0, rc0] = reactionEnvelopeTableData(ml, x);
[rSI, rcSI] = reactionEnvelopeTableData(ml, x, SI);
assert(isequal(rSI, r0) && isequal(rcSI, rc0), 'envelope table: SI = call without U');
assert(isequal(rc0, {'Node', 'x [m]', 'Component', 'Max', 'at x_v [m]', 'Min', 'at x_v [m]'}), 'SI headers as before M9');
[r, rc] = reactionEnvelopeTableData(ml, x, US);
assert(isequal(rc, {'Node', 'x [ft]', 'Component', 'Max', 'at x_v [ft]', 'Min', 'at x_v [ft]'}), 'US headers');
R = ml.reactions;
for k = 1:numel(R.dof)
    f = kip;
    component = 'force [kip]';
    if ~strcmp(R.component{k}, 'Fv')
        f = kip * ft;
        component = 'couple [kip*ft]';
    end
    assert(strcmp(r{k, 1}, r0{k, 1}) && strcmp(r{k, 3}, component), 'row %d: node and component', k);
    assert(showsFixed(r{k, 2}, x(R.node(k)) / ft, 3) && showsFixed(r{k, 5}, R.RmaxXv(k) / ft, 3) ...
        && showsFixed(r{k, 7}, R.RminXv(k) / ft, 3), 'row %d: x and x_v in ft', k);
    assert(showsFixed(r{k, 4}, R.Rmax(k) / f, 3) && showsFixed(r{k, 6}, R.Rmin(k) / f, 3), 'row %d: max and min', k);
end
assert(isequal(r(:, 3)', {'force [kip]', 'couple [kip*ft]', 'force [kip]'}), 'fixed support: force and couple rows');
res = analyzeVehiclePosition(prepareMovingLoad(propped, defaultEnvelopeStations(x, 4)), truck, 12, 1);
[t0, tc0] = currentReactionTableData(res, propped);
[tSI, tcSI] = currentReactionTableData(res, propped, SI);
assert(isequal(tSI, t0) && isequal(tcSI, tc0), 'current reactions: SI = call without U');
assert(isequal(tc0, {'Node', 'x [m]', 'Support', 'Force [kN] (+ up)', 'Couple [kN*m] (+ CCW)'}), 'SI headers as before M9');
[t, tc] = currentReactionTableData(res, propped, US);
assert(isequal(tc, {'Node', 'x [ft]', 'Support', 'Force [kip] (+ up)', 'Couple [kip*ft] (+ CCW)'}), 'US headers');
assert(isequal(t(:, [1 3]), t0(:, [1 3])) && showsFixed(t{1, 2}, 0, 3) && showsFixed(t{2, 2}, 20 / ft, 3) ...
    && showsFixed(t{1, 4}, res.R(1) / kip, 3) && showsFixed(t{2, 4}, res.R(17) / kip, 3) ...
    && showsFixed(t{1, 5}, res.R(2) / (kip * ft), 3) && strcmp(t{2, 5}, '-'), 'US reactions at x_v = 12 m');
reportComparisons('US reaction table at x_v = 12 m: forces add up to the truck', ...
    compareToReference('sum of shown forces [kip] = 320 kN / kip', str2double(t{1, 4}) + str2double(t{2, 4}), ...
    320e3 / kip, 0.01));
% Two-span beam: the end supports lift off, so the Min column and its x_v are not all zero
ml = runMovingLoad(twoSpan, truck, 'Step', 0.5);
R = ml.reactions;
assert(isequal(R.component(:)', {'Fv', 'Fv', 'Fv'}) && sum(R.Rmin < -kip) == 2 && sum(R.RminXv > 1) == 2, ...
    'two-span beam: both end supports lift off by more than 1 kip (so the Min factor matters)');
[r0, rc0] = reactionEnvelopeTableData(ml, xTwo);
[rSI, rcSI] = reactionEnvelopeTableData(ml, xTwo, SI);
assert(isequal(rSI, r0) && isequal(rcSI, rc0), 'two-span envelope table: SI = call without U');
[r, rc] = reactionEnvelopeTableData(ml, xTwo, US);
assert(isequal(rc, {'Node', 'x [ft]', 'Component', 'Max', 'at x_v [ft]', 'Min', 'at x_v [ft]'}), 'US headers');
for k = 1:numel(R.dof)
    assert(strcmp(r{k, 1}, r0{k, 1}) && strcmp(r{k, 3}, 'force [kip]'), 'two-span row %d: node and component', k);
    assert(showsFixed(r{k, 2}, xTwo(R.node(k)) / ft, 3) && showsFixed(r{k, 5}, R.RmaxXv(k) / ft, 3) ...
        && showsFixed(r{k, 7}, R.RminXv(k) / ft, 3), 'two-span row %d: x and x_v in ft', k);
    assert(showsFixed(r{k, 4}, R.Rmax(k) / kip, 3) && showsFixed(r{k, 6}, R.Rmin(k) / kip, 3), ...
        'two-span row %d: max and min in kip', k);
    % the SI table converted by hand: 0.001 kN rounding (0.0005 kN) plus 0.001 kip rounding (0.0005 kip)
    assert(abs(str2double(r{k, 6}) - str2double(r0{k, 6}) * 1e3 / kip) <= 0.0005 * (1e3 / kip + 1) + 1e-9 ...
        && abs(str2double(r{k, 4}) - str2double(r0{k, 4}) * 1e3 / kip) <= 0.0005 * (1e3 / kip + 1) + 1e-9, ...
        'two-span row %d: US = SI table / (kip / kN)', k);
end
fprintf('  two-span Min [kN]: %s; [kip]: %s\n', strjoin(r0(:, 6)', ' / '), strjoin(r(:, 6)', ' / '));
reportComparisons('US reaction envelope, two-span beam: minimum (lift-off) at the end supports', [ ...
    compareToReference('node 1 Min [kip] = Rmin / kip', str2double(r{1, 6}), R.Rmin(1) / kip, 0.01), ...
    compareToReference('node 19 Min [kip] = Rmin / kip', str2double(r{3, 6}), R.Rmin(3) / kip, 0.02)]);

%% Damage comparison table and findings: extremes and reactions in US units, percentages unchanged
damaged = applyStiffnessDamage(propped, 1:2, 0.5);
cmp = compareHealthyDamaged(propped, damaged, truck, 'Step', 0.5);
[d0, c0] = damageComparisonTableData(cmp);
[dSI, cSI] = damageComparisonTableData(cmp, SI);
assert(isequal(dSI, d0) && isequal(cSI, c0), 'SI = call without U');
[d, c] = damageComparisonTableData(cmp, US);
assert(isequal(c, c0) && isequal(size(d), size(d0)) && isequal(d(:, 5), d0(:, 5)), ...
    'headers and percentages do not depend on the units');
factor = struct('M', kip * ft, 'V', kip, 'v', inch);
unitText = struct('M', 'kip*ft', 'V', 'kip', 'v', 'in');
name = struct('M', 'Moment M', 'V', 'Shear V', 'v', 'Deflection v');
for k = 1:numel(cmp.critical)
    cr = cmp.critical(k);
    f = factor.(cr.quantity);
    assert(strcmp(d{k, 1}, sprintf('%s %s [%s]', name.(cr.quantity), cr.extreme, unitText.(cr.quantity))) ...
        && showsFixed(d{k, 2}, cr.healthy / f, 3) && showsFixed(d{k, 3}, cr.damaged / f, 3) ...
        && showsFixed(d{k, 4}, cr.change / f, 3), 'extreme row %d in US units', k);
end
row = numel(cmp.critical);
for k = 1:numel(cmp.reactions)
    rr = cmp.reactions(k);
    if ~strcmp(rr.component, 'Fv')
        continue
    end
    assert(strcmp(d{row + 1, 1}, sprintf('Reaction at node %d max [kip]', rr.node)) ...
        && showsFixed(d{row + 1, 2}, rr.healthyMax / kip, 3) && showsFixed(d{row + 1, 3}, rr.damagedMax / kip, 3) ...
        && showsFixed(d{row + 1, 4}, rr.changeMax / kip, 3), 'node %d max reaction in kip', rr.node);
    assert(strcmp(d{row + 2, 1}, sprintf('Reaction at node %d min [kip]', rr.node)) ...
        && showsFixed(d{row + 2, 2}, rr.healthyMin / kip, 3) && showsFixed(d{row + 2, 3}, rr.damagedMin / kip, 3) ...
        && showsFixed(d{row + 2, 4}, rr.changeMin / kip, 3), 'node %d min reaction in kip', rr.node);
    row = row + 2;
end
assert(row == size(d, 1), 'one max and one min row per vertical reaction');
lines0 = damageComparisonSummary(cmp, propped);
assert(isequal(damageComparisonSummary(cmp, propped, SI), lines0), 'findings: SI = call without U');
lines = damageComparisonSummary(cmp, propped, US);
fprintf('  %s\n', lines{:});
assert(numel(lines) == 3 && strcmp(lines{1}, lines0{1}), 'determinacy line does not depend on the units');
pct = abs([cmp.critical.pctChange]);
pct(isnan(pct)) = -Inf;
[~, i] = max(pct);
cr = cmp.critical(i);
tok = regexp(lines{2}, ', (\S+) -> (\S+) (\S+) \(', 'tokens', 'once');
assert(numel(tok) == 3 && showsFixed(tok{1}, cr.healthy / factor.(cr.quantity), 3) ...
    && showsFixed(tok{2}, cr.damaged / factor.(cr.quantity), 3) && strcmp(tok{3}, unitText.(cr.quantity)), ...
    'largest change of an extreme in US units');
tok = regexp(lines{3}, 'node (\d+) (max|min), (\S+) -> (\S+) kip \(', 'tokens', 'once');
tok0 = regexp(lines0{3}, 'node (\d+) (max|min), (\S+) -> (\S+) kN \(', 'tokens', 'once');
assert(numel(tok) == 4 && isequal(tok(1:2), tok0(1:2)), 'same reaction named as in SI');
rr = cmp.reactions([cmp.reactions.node] == str2double(tok{1}) & strcmp({cmp.reactions.component}, 'Fv'));
before = rr.healthyMax;
after = rr.damagedMax;
if strcmp(tok{2}, 'min')
    before = rr.healthyMin;
    after = rr.damagedMin;
end
assert(showsFixed(tok{3}, before / kip, 3) && showsFixed(tok{4}, after / kip, 3), 'largest reaction change in kip');
fprintf('  PASS SI unchanged; %d US rows and the findings = SI quantities / factor; percentages unchanged\n', size(d, 1));
% Two-span beam, EI loss next to the middle support: the minimum (lift-off) reactions at the end supports are
% not zero and change, so the min rows and the findings test the force factor (on the propped cantilever all are 0)
damaged = applyStiffnessDamage(twoSpan, 13:14, 0.5);
cmp = compareHealthyDamaged(twoSpan, damaged, truck, 'Step', 0.5);
assert(isequal({cmp.reactions.component}, {'Fv', 'Fv', 'Fv'}), 'two-span beam: three vertical reactions');
assert(sum(abs([cmp.reactions.healthyMin]) > kip & abs([cmp.reactions.damagedMin]) > kip ...
    & abs([cmp.reactions.changeMin]) > 0.1 * kip) == 2, ...
    'two-span beam: both end supports lift off by more than 1 kip and their minimum changes by more than 0.1 kip');
[d0, c0] = damageComparisonTableData(cmp);
[dSI, cSI] = damageComparisonTableData(cmp, SI);
assert(isequal(dSI, d0) && isequal(cSI, c0), 'two-span: SI = call without U');
[d, c] = damageComparisonTableData(cmp, US);
assert(isequal(c, c0) && isequal(size(d), size(d0)) && isequal(d(:, 5), d0(:, 5)) ...
    && size(d, 1) == numel(cmp.critical) + 6, 'two-span: headers, percentages and rows do not depend on the units');
for k = 1:numel(cmp.critical)
    cr = cmp.critical(k);
    f = factor.(cr.quantity);
    assert(showsFixed(d{k, 2}, cr.healthy / f, 3) && showsFixed(d{k, 3}, cr.damaged / f, 3) ...
        && showsFixed(d{k, 4}, cr.change / f, 3), 'two-span extreme row %d in US units', k);
end
row = numel(cmp.critical);
tolSum = 0.0005 * (1e3 / kip + 1) + 1e-9;    % 0.001 kN rounding (0.0005 kN) plus 0.001 kip rounding (0.0005 kip)
for k = 1:numel(cmp.reactions)
    rr = cmp.reactions(k);
    assert(strcmp(d{row + 1, 1}, sprintf('Reaction at node %d max [kip]', rr.node)) ...
        && showsFixed(d{row + 1, 2}, rr.healthyMax / kip, 3) && showsFixed(d{row + 1, 3}, rr.damagedMax / kip, 3) ...
        && showsFixed(d{row + 1, 4}, rr.changeMax / kip, 3), 'two-span node %d max reaction in kip', rr.node);
    assert(strcmp(d{row + 2, 1}, sprintf('Reaction at node %d min [kip]', rr.node)) ...
        && showsFixed(d{row + 2, 2}, rr.healthyMin / kip, 3) && showsFixed(d{row + 2, 3}, rr.damagedMin / kip, 3) ...
        && showsFixed(d{row + 2, 4}, rr.changeMin / kip, 3), 'two-span node %d min reaction in kip', rr.node);
    for col = 2:4                                % the SI table converted by hand, max and min rows
        assert(abs(str2double(d{row + 1, col}) - str2double(d0{row + 1, col}) * 1e3 / kip) <= tolSum ...
            && abs(str2double(d{row + 2, col}) - str2double(d0{row + 2, col}) * 1e3 / kip) <= tolSum, ...
            'two-span node %d, column %d: US = SI table / (kip / kN)', rr.node, col);
    end
    row = row + 2;
end
lines0 = damageComparisonSummary(cmp, twoSpan);
assert(isequal(damageComparisonSummary(cmp, twoSpan, SI), lines0), 'two-span findings: SI = call without U');
lines = damageComparisonSummary(cmp, twoSpan, US);
fprintf('  %s\n', lines{:});
tok = regexp(lines{3}, 'node (\d+) (max|min), (\S+) -> (\S+) kip \(', 'tokens', 'once');
tok0 = regexp(lines0{3}, 'node (\d+) (max|min), (\S+) -> (\S+) kN \(', 'tokens', 'once');
assert(numel(tok) == 4 && isequal(tok(1:2), tok0(1:2)) && strcmp(tok{2}, 'min'), ...
    'two-span findings: the largest reaction change is a minimum (lift-off), named as in SI');
rr = cmp.reactions([cmp.reactions.node] == str2double(tok{1}));
assert(showsFixed(tok{3}, rr.healthyMin / kip, 3) && showsFixed(tok{4}, rr.damagedMin / kip, 3), ...
    'two-span findings: largest (minimum) reaction change in kip');
reportComparisons('US damage comparison, two-span beam: minimum reaction at node 1 (lift-off)', [ ...
    compareToReference('healthy min [kip] = healthyMin / kip', str2double(d{numel(cmp.critical) + 2, 2}), ...
    cmp.reactions(1).healthyMin / kip, 0.01), ...
    compareToReference('damaged min [kip] = damagedMin / kip', str2double(d{numel(cmp.critical) + 2, 3}), ...
    cmp.reactions(1).damagedMin / kip, 0.01), ...
    compareToReference('change of min [kip] = changeMin / kip', str2double(d{numel(cmp.critical) + 2, 4}), ...
    cmp.reactions(1).changeMin / kip, 0.05)]);
fprintf('  PASS two-span: non-zero min rows and the findings in kip = SI quantities / factor\n');

%% Findings: a reaction change below the last decimal shown in the chosen force unit counts as unchanged
same = compareHealthyDamaged(propped, propped, truck, 'Step', 1);
lines0 = damageComparisonSummary(same, propped);
lines = damageComparisonSummary(same, propped, US);
assert(strcmp(lines0{3}, 'Vertical reactions: unchanged (to 0.001 kN).') ...
    && strcmp(lines{3}, 'Vertical reactions: unchanged (to 0.001 kip).'), 'no change in either unit');
k = find(strcmp({same.reactions.component}, 'Fv'), 1);
same.reactions(k).damagedMax = same.reactions(k).healthyMax + 2;     % 2 N = 0.002 kN = 0.00045 kip
same.reactions(k).changeMax = 2;
same.reactions(k).pctChangeMax = 200 / same.reactions(k).healthyMax;
lines0 = damageComparisonSummary(same, propped);
lines = damageComparisonSummary(same, propped, US);
assert(~isempty(strfind(lines0{3}, 'Largest reaction change')) && ~isempty(strfind(lines0{3}, ' kN (')) ...
    && strcmp(lines{3}, 'Vertical reactions: unchanged (to 0.001 kip).'), '2 N: shown in kN, below 0.0005 kip');
same.reactions(k).damagedMax = same.reactions(k).healthyMax + 3;     % 3 N = 0.00067 kip, shown as 0.001
same.reactions(k).changeMax = 3;
lines = damageComparisonSummary(same, propped, US);
assert(~isempty(strfind(lines{3}, 'Largest reaction change')) && ~isempty(strfind(lines{3}, ' kip (')), ...
    '3 N: shown as a change of 0.001 kip');
fprintf('  PASS 2 N is a change in kN but not in kip; 3 N is a change in both\n');

%% Sensitivity table and bar chart: coordinates in ft, deflection in in
s = damageSensitivity(propped, truck, 0.30, 'vmin', 'Step', 1, 'Refine', false);
[d0, c0] = sensitivityTableData(s, propped);
[dSI, cSI] = sensitivityTableData(s, propped, SI);
assert(isequal(dSI, d0) && isequal(cSI, c0), 'table: SI = call without U');
assert(isequal(c0, {'Rank', 'Elements', 'x [m]', 'vmin [mm]', 'Change', 'Change [%]'}), 'SI headers as before M9');
[d, c] = sensitivityTableData(s, propped, US);
assert(isequal(c, {'Rank', 'Elements', 'x [ft]', 'vmin [in]', 'Change', 'Change [%]'}), 'US headers');
assert(isequal(d(:, [1 2 6]), d0(:, [1 2 6])), 'rank, elements and percentages do not depend on the units');
x = propped.nodes.x;
for k = 1:size(d, 1)
    g = s.rank(k);
    els = s.groups{g};
    range = regexp(d{k, 3}, '-', 'split');
    assert(numel(range) == 2 && showsG(range{1}, x(min(els)) / ft) && showsG(range{2}, x(max(els) + 1) / ft), ...
        'row %d: x range in ft', k);
    assert(showsFixed(d{k, 4}, s.values(g) / inch, 4) && showsFixed(d{k, 5}, s.change(g) / inch, 4), ...
        'row %d: vmin and change in in', k);
end
color = [0.580 0.235 0.557];
ax0 = RecordingAxes();
axSI = RecordingAxes();
ax = RecordingAxes();
plotSensitivity(ax0, s, propped, color);
plotSensitivity(axSI, s, propped, color, SI);
plotSensitivity(ax, s, propped, color, US);
chart0 = recorded(ax0);
chart = recorded(ax);
assert(isequal(recorded(axSI), chart0), 'chart: SI = call without U');
assert(strcmp(chart0.XLabel, 'location of the loss, x [m]') && strcmp(chart0.YLabel, 'change of vmin [mm]'), 'SI labels');
assert(strcmp(chart.XLabel, 'location of the loss, x [ft]') && strcmp(chart.YLabel, 'change of vmin [in]') ...
    && strcmp(chart.Title, chart0.Title), 'US labels');
assert(numel(chart.Objects) == numel(chart0.Objects) && numel(chart.Objects) == numel(s.groups) + 1, ...
    'one bar per group + axis line');
for k = 1:numel(s.groups)
    patchK = chart.Objects(k);
    assert(strcmp(patchK.kind, 'patch') && max(abs(patchK.x * ft - chart0.Objects(k).x)) < 1e-12 ...
        && max(abs(patchK.y * inch - chart0.Objects(k).y * 1e-3)) < 1e-15, 'bar %d in ft and in', k);
    assert(max(abs(patchK.y * inch - [0 0 1 1] * s.change(k))) < 1e-15, 'bar %d: height = change of vmin', k);
end
assert(max(abs(chart.XLim * ft - [0 20])) < 1e-12, 'x axis: the beam in ft');
fprintf('  PASS table and chart: SI unchanged; US x in ft, vmin and changes in in\n');

%% Candidate table and summary of the Stage 3 search: regions in ft, RMSE and absolute noise in in
model = createBeamModel(generateUniformMesh(20, 20), 2e9);   % 1 m elements
model = addSupport(model, 1, 'pin');
model = addSupport(model, 21, 'roller');
positions = [5 10 15 20 25];
sensors = [5 10 15];
[u, truth] = syntheticObservations(model, truck, positions, sensors, 1, 6, 7, 30, 1, 7);
r = identifySingleDamage(model, truck, positions, sensors, u, 'NoiseLevel', 0.01, 'NoiseAbsolute', 5e-5, ...
    'Groups', {2; 5; 7; 10; 15});
[d0, c0] = identificationTableData(r);
[dSI, cSI] = identificationTableData(r, SI);
assert(isequal(dSI, d0) && isequal(cSI, c0), 'table: SI = call without U');
assert(strcmp(c0{1}, 'Region x [m]') && strcmp(c0{6}, 'RMSE [mm]'), 'SI headers as before M9');
[d, c] = identificationTableData(r, US);
assert(isequal(c, [{'Region x [ft]'}, c0(2:5), {'RMSE [in]'}, c0(7)]), 'US headers');
assert(isequal(size(d), size(d0)) && isequal(d(:, [2:5, 7]), d0(:, [2:5, 7])), 'unit-free columns unchanged');
for k = 1:numel(r.competing)
    range = regexp(d{k, 1}, '-', 'split');
    assert(showsG(range{1}, r.competing(k).x(1) / ft) && showsG(range{2}, r.competing(k).x(2) / ft) ...
        && showsFixed(d{k, 6}, r.competing(k).J / inch, 4), 'candidate %d: region in ft, RMSE in in', k);
end
if size(d, 1) > numel(r.competing)
    assert(showsFixed(d{end, 6}, r.Jhealthy / inch, 4), 'healthy row: RMSE in in');
end
[lines0, flags0] = identificationSummary(r, truth);
[linesSI, flagsSI] = identificationSummary(r, truth, SI);
assert(isequal(linesSI, lines0) && isequal(flagsSI, flags0), 'summary: SI = call without U');
[lines, flags] = identificationSummary(r, truth, US);
fprintf('  %s\n', lines{1:3});
assert(numel(lines) == numel(lines0) && numel(flags) == numel(flags0), 'same lines and flags');
assert(~isempty(strfind(lines0{1}, '+ 0.05 mm;')), 'SI absolute noise in mm');
tok = regexp(lines{1}, '\+ (\S+) in;', 'tokens', 'once');
assert(numel(tok) == 1 && showsG(tok{1}, 5e-5 / inch), 'US absolute noise in in');
tok = regexp(lines{2}, 'x = (\S+)-(\S+) ft\).*RMSE (\S+) in,', 'tokens', 'once');
assert(numel(tok) == 3 && showsG(tok{1}, r.best.x(1) / ft) && showsG(tok{2}, r.best.x(2) / ft) ...
    && showsFixed(tok{3}, r.best.J / inch, 4), 'best fit: region in ft, RMSE in in');
tok = regexp(lines{3}, '(\S+)-(\S+) ft', 'tokens');
assert(numel(tok) == size(r.uncertaintyRegions, 1), 'every region of uncertainty in ft');
for k = 1:numel(tok)
    assert(showsG(tok{k}{1}, r.uncertaintyRegions(k, 1) / ft) && showsG(tok{k}{2}, r.uncertaintyRegions(k, 2) / ft), ...
        'region %d in ft', k);
end
synthetic = find(~cellfun(@isempty, strfind(lines, 'Synthetic test case')));
assert(numel(synthetic) == 1, 'one line on the hidden case');
tok = regexp(lines{synthetic}, 'x = (\S+)-(\S+) ft\)', 'tokens', 'once');
assert(numel(tok) == 2 && showsG(tok{1}, 6 / ft) && showsG(tok{2}, 7 / ft), 'hidden case in ft');
minimum = find(~cellfun(@isempty, strfind(lines, 'Minimum-RMSE candidate')));
if ~isempty(minimum)
    tok = regexp(lines{minimum}, 'RMSE (\S+) in\.', 'tokens', 'once');
    assert(numel(tok) == 1 && showsFixed(tok{1}, r.minRMSE.J / inch, 4), 'minimum-RMSE candidate: RMSE in in');
end
text = strjoin(lines', ' ');
assert(isempty(regexp(text, '\d mm?[^a-z]', 'once')), 'no SI unit left in the US summary');
for k = 1:numel(lines0)
    if isempty(regexp(lines0{k}, '\d mm?[^a-z]', 'once'))
        assert(strcmp(lines{k}, lines0{k}), 'line %d has no units and does not change', k);
    end
end
[u3, truth3] = syntheticObservations(model, truck, positions, sensors, 1, 6, 7, 0, 2, 3);
r3 = identifySingleDamage(model, truck, positions, sensors, u3, 'NoiseLevel', 0.02, 'Groups', {6; 7; 8});
assert(~r3.damageDetected && ~isempty(r3.competing), 'this realization: healthy best, damage not ruled out');
[l3, f3] = identificationSummary(r3, truth3, US);
[l30, f30] = identificationSummary(r3, truth3);
assert(isequal(identificationSummary(r3, truth3, SI), l30), 'healthy best: SI = call without U');
tok = regexp(l3{2}, 'NO DAMAGE .*RMSE (\S+) in\.', 'tokens', 'once');
assert(numel(tok) == 1 && showsFixed(tok{1}, r3.best.J / inch, 4), 'healthy best: RMSE in in');
tok = regexp(l3{3}, 'ruled out in: (\S+)-(\S+) ft', 'tokens', 'once');
assert(numel(tok) == 2 && showsG(tok{1}, r3.uncertaintyRegions(1, 1) / ft) && showsG(tok{2}, r3.uncertaintyRegions(1, 2) / ft) ...
    && numel(f3) == numel(f30) && ~isempty(strfind(f3{1}, ' ft')), 'damage cannot be ruled out: region in ft (also as a flag)');
d3 = identificationTableData(r3, US);
assert(strcmp(d3{1, 1}, 'no damage (healthy)') && showsFixed(d3{1, 6}, r3.Jhealthy / inch, 4), 'healthy row first, RMSE in in');
fprintf('  PASS table and summary: SI unchanged; US regions in ft, RMSE and absolute noise in in\n');

%% Fit profile, fit chart and readings chart in US units
model = createBeamModel(generateUniformMesh(20, 20), 2e9);
model = addSupport(model, 1, 'pin');
model = addSupport(model, 21, 'roller');
positions = [5 10 15 20 25];
sensors = [5 10 15];
u = syntheticObservations(model, truck, positions, sensors, 1, 6, 7, 30, 1, 7);
r = identifySingleDamage(model, truck, positions, sensors, u, 'NoiseLevel', 0.01, 'Groups', {2; 5; 7; 10; 15});
th = appTheme();
x = model.nodes.x;
p0 = fitProfileData(r, model);
assert(isequal(fitProfileData(r, model, SI), p0), 'fit profile: SI = call without U');
p = fitProfileData(r, model, US);
names = fieldnames(p0);
assert(isequal(fieldnames(p), names), 'same fields');
for k = 1:numel(names)
    if any(strcmp(names{k}, {'x1', 'x2'}))
        assert(max(abs(p.(names{k}) * ft - p0.(names{k}))) < 1e-12, '%s in ft', names{k});
    else
        assert(isequal(p.(names{k}), p0.(names{k})), '%s does not depend on the units', names{k});
    end
end
ax0 = RecordingAxes();
axSI = RecordingAxes();
ax = RecordingAxes();
plotFitProfile(ax0, p0, x, th);
plotFitProfile(axSI, p0, x, th, SI);
plotFitProfile(ax, p, x / ft, th, US);
chart0 = recorded(ax0);
chart = recorded(ax);
assert(isequal(recorded(axSI), chart0), 'fit chart: SI = call without U');
assert(strcmp(chart0.XLabel, 'candidate region x [m]') && strcmp(chart.XLabel, 'candidate region x [ft]') ...
    && strcmp(chart.YLabel, chart0.YLabel) && isequal(chart.Legend, chart0.Legend) && isequal(chart.YLim, chart0.YLim), ...
    'fit chart labels');
assert(numel(chart.Objects) == numel(chart0.Objects) && max(abs(chart.XLim * ft - chart0.XLim)) < 1e-12, ...
    'same objects; x axis in ft');
for k = 1:numel(chart.Objects)
    assert(strcmp(chart.Objects(k).kind, chart0.Objects(k).kind) ...
        && max(abs(chart.Objects(k).x * ft - chart0.Objects(k).x)) < 1e-12 ...
        && isequal(chart.Objects(k).y, chart0.Objects(k).y), 'fit chart object %d: x in ft, fit measure unchanged', k);
end
for withBest = [false true]
    best = [];
    if withBest
        best = r.best.u;
    end
    ax0 = RecordingAxes();
    axSI = RecordingAxes();
    ax = RecordingAxes();
    plotReadings(ax0, positions, sensors, u, r.uHealthy, best, th);
    plotReadings(axSI, positions, sensors, u, r.uHealthy, best, th, SI);
    plotReadings(ax, positions, sensors, u, r.uHealthy, best, th, US);
    chart0 = recorded(ax0);
    chart = recorded(ax);
    assert(isequal(recorded(axSI), chart0), 'readings chart: SI = call without U');
    assert(strcmp(chart0.XLabel, 'truck front-axle position x_v [m]') && strcmp(chart0.YLabel, 'deflection [mm]') ...
        && isequal(chart0.Legend, {'S1 (x = 5 m)', 'S2 (x = 10 m)', 'S3 (x = 15 m)'}), 'SI labels as before M9');
    assert(strcmp(chart.XLabel, 'truck front-axle position x_v [ft]') && strcmp(chart.YLabel, 'deflection [in]') ...
        && isequal(chart.Title, chart0.Title) && isequal(chart.LegendHandles, chart0.LegendHandles), 'US labels');
    for i = 1:numel(sensors)
        tok = regexp(chart.Legend{i}, sprintf('^S%d \\(x = (\\S+) ft\\)$', i), 'tokens', 'once');
        assert(numel(tok) == 1 && showsG(tok{1}, sensors(i) / ft), 'legend: sensor %d in ft', i);
    end
    perSensor = 2 + withBest;
    assert(numel(chart.Objects) == perSensor * numel(sensors), 'healthy, (best fit) and readings per sensor');
    for i = 1:numel(sensors)
        drawn = {r.uHealthy, best, u};
        drawn = drawn(~cellfun(@isempty, drawn));
        for j = 1:perSensor
            o = chart.Objects((i - 1) * perSensor + j);
            assert(max(abs(o.x * ft - positions)) < 1e-12 && max(abs(o.y * inch - drawn{j}(i, :))) < 1e-15, ...
                'sensor %d, line %d: positions in ft, deflections in in', i, j);
        end
    end
    assert(max(abs(chart.XLim * ft - chart0.XLim)) < 1e-12, 'x axis in ft');
end
fprintf('  PASS fit profile (x1, x2 in ft), fit chart and readings chart (x in ft, deflections in in); SI unchanged\n');

%% Stage 3 inputs: readings and absolute noise typed in in, region sizes in ft, both returned in m
model = createBeamModel(generateUniformMesh(20, 20), 2e9);
model = addSupport(model, 1, 'pin');
model = addSupport(model, 21, 'roller');
mm = [-5 NaN; -10.5 -2];
assert(isequaln(readingsFromTable(mm, 2, 2, SI), readingsFromTable(mm, 2, 2)) ...
    && isequaln(readingsFromTable({-5, []; '-10.5', -2}, 2, 2, SI), readingsFromTable({-5, []; '-10.5', -2}, 2, 2)), ...
    'readings: SI = call without U');
in = [-0.2 NaN; -0.41 -0.08];
uIn = readingsFromTable(in, 2, 2, US);
assert(isequal(isnan(uIn), isnan(in)) && max(abs(uIn(~isnan(in)) - in(~isnan(in)) * inch)) < 1e-15, 'in to m, missing stays NaN');
uIn = readingsFromTable({-0.2, []; '-0.41', -0.08}, 2, 2, US);
assert(isequal(isnan(uIn), isnan(in)) && max(abs(uIn(~isnan(in)) - in(~isnan(in)) * inch)) < 1e-15, 'cell input in in');
assertThrows(@() readingsFromTable([-5 Inf; 1 2], 2, 2, US), 'BridgeFE:invalidInput');
try
    readingsFromTable([-5 Inf; 1 2], 2, 2, US);
catch err
    assert(~isempty(strfind(err.message, 'finite numbers in in')), 'error names the unit');
end
[len0, items0] = candidateRegionLength();
[lenSI, itemsSI] = candidateRegionLength([], SI);
assert(isempty(len0) && isempty(lenSI) && isequal(itemsSI, items0) ...
    && isequal(items0, {'Each element', '2 m regions', '4 m regions'}), 'SI items as before M9');
for k = 1:3
    assert(isequal(candidateRegionLength(items0{k}, SI), candidateRegionLength(items0{k})), 'SI = call without U');
end
assert(isequal(arrayfun(@(k) candidateRegionLength(items0{k}), 1:3), [0 2 4]), 'SI lengths in m');
[lenUS, itemsUS] = candidateRegionLength([], US);
assert(isempty(lenUS) && isequal(itemsUS, {'Each element', '6 ft regions', '12 ft regions'}), 'US items');
lengths = arrayfun(@(k) candidateRegionLength(itemsUS{k}, US), 1:3);
assert(max(abs(lengths - [0 6 12] * ft)) < 1e-12 && max(abs(lengths - [0 1.8288 3.6576])) < 1e-12, 'US lengths in m');
assertThrows(@() candidateRegionLength('2 m regions', US), 'BridgeFE:invalidInput');
assertThrows(@() candidateRegionLength('6 ft regions'), 'BridgeFE:invalidInput');
assert(isequal(identificationOptions(model, 2, 1.5, 0.05, -1, SI), identificationOptions(model, 2, 1.5, 0.05, -1)) ...
    && isequal(identificationOptions(model, 0, 0, 0, 1, SI), identificationOptions(model, 0, 0, 0, 1)), ...
    'options: SI = call without U');
opts = identificationOptions(model, candidateRegionLength('6 ft regions', US), 1.5, 0.002, 1, US);
assert(isequal(opts(1:4), {'Direction', 1, 'Groups', candidateGroups(model, 6 * ft)}) && strcmp(opts{5}, 'NoiseLevel') ...
    && opts{6} == 0.015 && strcmp(opts{7}, 'NoiseAbsolute') && abs(opts{8} - 0.002 * inch) < 1e-18, ...
    '6 ft regions, 1.5 % and 0.002 in = 5.08e-5 m');
assertThrows(@() identificationOptions(model, 0, 0, -0.001, 1, US), 'BridgeFE:invalidInput');
try
    identificationOptions(model, 0, 0, -0.001, 1, US);
catch err
    assert(~isempty(strfind(err.message, 'Absolute noise [in]')), 'error names the unit');
end
fprintf('  PASS readings and absolute noise in in -> m; region sizes 6 ft and 12 ft -> 1.8288 m and 3.6576 m\n');

%% Node choices for the region drop-downs: labels in the display length, coordinates in m
model = createBeamModel(generateUniformMesh(20, 16), 2e9);   % 1.25 m elements
[labels0, x0] = nodeChoices(model);
[labelsSI, xSI] = nodeChoices(model, SI);
assert(isequal(labelsSI, labels0) && isequal(xSI, x0), 'SI = call without U');
assert(iscellstr(labels0) && isequal(size(labels0), [1 17]) && isequal(x0, model.nodes.x'), 'one entry per node, rows');
assert(strcmp(labels0{1}, 'node 1 (x = 0 m)') && strcmp(labels0{7}, 'node 7 (x = 7.5 m)') ...
    && strcmp(labels0{17}, 'node 17 (x = 20 m)'), 'SI labels');
[labels, xUS] = nodeChoices(model, US);
assert(isequal(xUS, x0) && isequal(size(labels), [1 17]), 'coordinates stay in m');
for k = 1:17
    tok = regexp(labels{k}, sprintf('^node %d \\(x = (\\S+) ft\\)$', k), 'tokens', 'once');
    assert(numel(tok) == 1 && showsG(tok{1}, x0(k) / ft), 'node %d label in ft', k);
end
fprintf('  US labels: ''%s'', ''%s''\n', labels{7}, labels{17});
two = createBeamModel(meshSpans([12 15], [8 10]), 2e9);
[labels, x2] = nodeChoices(two, US);
assert(numel(labels) == 19 && isequal(x2, two.nodes.x') && strcmp(labels{9}, sprintf('node 9 (x = %g ft)', 12 / ft)), ...
    'two spans: 19 nodes, support B at 12 m');
fprintf('  PASS one label per node in m or ft; coordinates always in m\n');

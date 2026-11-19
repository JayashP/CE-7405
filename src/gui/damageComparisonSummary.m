function lines = damageComparisonSummary(cmp, model, U)
%DAMAGECOMPARISONSUMMARY Plain-language findings of a healthy vs damaged comparison.
%   LINES = DAMAGECOMPARISONSUMMARY(CMP, MODEL) returns a cell column of
%   text lines for the app's Damage tab, from the COMPAREHEALTHYDAMAGED
%   result CMP and the healthy MODEL:
%     1. whether the beam is statically determinate (2 restrained DOFs, so
%        reactions, shears and moments follow from equilibrium alone and
%        cannot change with EI) or indeterminate (degree = restrained DOFs - 2,
%        so an EI loss redistributes them);
%     2. the global extreme with the largest signed % change, and whether
%        its magnitude grew or shrank;
%     3. the largest change of a vertical reaction (or that none changed to
%        the 0.001 kN shown).
%   LINES = DAMAGECOMPARISONSUMMARY(CMP, MODEL, U) states the values in the
%   display units U of UNITSYSTEM (QUANTITYDISPLAY; reactions in U.force,
%   unchanged meaning less than the 0.001 U.force shown).
%
%   See also COMPAREHEALTHYDAMAGED, DAMAGECOMPARISONTABLEDATA, UNITSYSTEM.

if nargin < 3 || isempty(U)
    U = unitSystem('SI');
end
force = U.force;
[~, restrained] = partitionDofs(model);
degree = numel(restrained) - 2;
if degree == 0
    lines = {['Statically determinate beam: reactions, shears and moments follow from equilibrium alone, ' ...
        'so the EI loss cannot change them. Only deflections change.']};
else
    lines = {sprintf(['Statically indeterminate beam (degree %d): the EI loss redistributes reactions, ' ...
        'shears and moments, and increases deflections.'], degree)};
end

pct = [cmp.critical.pctChange];
size_ = abs(pct);
size_(isnan(size_)) = -Inf;
[largest, i] = max(size_);
if isempty(i) || ~isfinite(largest) || round(100 * largest) == 0
    lines{end+1, 1} = 'Largest change of an extreme: none (to the decimals shown).';
else
    c = cmp.critical(i);
    q = quantityDisplay(c.quantity, U);
    trend = 'smaller magnitude';
    if abs(c.damaged) > abs(c.healthy)
        trend = 'larger magnitude';
    end
    lines{end+1, 1} = sprintf('Largest change of an extreme: %s %s, %s -> %s %s (%s %%, %s).', q.label, c.extreme, ...
        formatNumber(c.healthy * q.scale, 3), formatNumber(c.damaged * q.scale, 3), q.unit, ...
        formatNumber(c.pctChange, 2, true), trend);
end

best = 0;
text = sprintf('Vertical reactions: unchanged (to 0.001 %s).', force.unit);
shown = 1e-3 * force.toSI;                  % the last decimal shown, 0.001 of the display unit, in N (1 for kN)
for k = 1:numel(cmp.reactions)
    r = cmp.reactions(k);
    if ~strcmp(r.component, 'Fv')
        continue
    end
    pairs = {'max', r.healthyMax, r.damagedMax, r.changeMax, r.pctChangeMax; ...
        'min', r.healthyMin, r.damagedMin, r.changeMin, r.pctChangeMin};
    for j = 1:2
        change = abs(pairs{j, 4});
        if round(change / shown) > 0 && change > best    % shown as at least 0.001 (0.5 N or more for kN)
            best = change;
            text = sprintf('Largest reaction change: node %d %s, %s -> %s %s (%s %%).', r.node, pairs{j, 1}, ...
                formatNumber(pairs{j, 2} / force.toSI, 3), formatNumber(pairs{j, 3} / force.toSI, 3), force.unit, ...
                formatNumber(pairs{j, 5}, 2, true));
        end
    end
end
lines{end+1, 1} = text;
end

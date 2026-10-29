function reportComparisons(title, rows)
%REPORTCOMPARISONS Print a verification table and error if any row failed.
%   REPORTCOMPARISONS(TITLE, ROWS) prints actual vs expected values, the
%   absolute and percentage errors, the criterion and PASS/FAIL for each
%   row from COMPARETOREFERENCE, then throws
%   'BridgeFE:test:referenceMismatch' listing the failed quantities, if any.

fprintf('\n%s\n', title);
fprintf('  %-44s %22s %22s %11s %12s %-13s %s\n', ...
    'Quantity', 'Actual', 'Expected', 'Abs error', 'Rel error %', 'Criterion', 'Result');
for k = 1:numel(rows)
    r = rows(k);
    if isnan(r.relErrorPct)
        relText = 'n/a';
    else
        relText = sprintf('%.3e', r.relErrorPct);
    end
    if r.pass
        status = 'PASS';
    else
        status = 'FAIL';
    end
    fprintf('  %-44s %22.14g %22.14g %11.3e %12s %-13s %s\n', ...
        r.quantity, r.actual, r.expected, r.absError, relText, r.criterion, status);
end

failed = {rows(~[rows.pass]).quantity};
if ~isempty(failed)
    error('BridgeFE:test:referenceMismatch', '%s: %d check(s) failed: %s', ...
        title, numel(failed), strjoin(failed, '; '));
end
end

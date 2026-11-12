function [data, columns] = identificationTableData(result)
%IDENTIFICATIONTABLEDATA Candidate regions in the region of uncertainty, as table text (Stage 3).
%   [DATA, COLUMNS] = IDENTIFICATIONTABLEDATA(RESULT) lists the competing
%   groups of an IDENTIFYSINGLEDAMAGE RESULT, best first: region [m],
%   elements, best loss d [%], d range inside the region [%], remaining EI
%   factor 1 - d, RMSE [mm] and the method's measure (S - S_best for the
%   noise-based region, RMSE / best RMSE otherwise). "No damage (healthy)"
%   is a row too: the first one when the healthy model fits best, the last
%   one when it is inside the region behind a damaged best fit.
%   The measures rank fits; they are not probabilities.
%
%   See also IDENTIFYSINGLEDAMAGE, FITPROFILEDATA.

likelihood = strcmp(result.method, 'likelihood');
measure = 'RMSE / best';
if likelihood
    measure = 'S - S_best';
end
columns = {'Region x [m]', 'Elements', 'Best d [%]', 'd range [%]', 'Remaining EI', 'RMSE [mm]', measure};
c = result.competing;
data = cell(numel(c), numel(columns));
for k = 1:numel(c)
    els = c(k).elements;
    elementText = sprintf('%d', els(1));
    if numel(els) > 1
        elementText = sprintf('%d-%d', min(els), max(els));
    end
    if likelihood
        m = formatNumber(c(k).deltaS, 2);
    else
        m = formatNumber(c(k).ratio, 3);
    end
    data(k, :) = {sprintf('%g-%g', c(k).x(1), c(k).x(2)), elementText, formatNumber(100 * c(k).d, 1), ...
        sprintf('%s-%s', formatNumber(100 * c(k).dRange(1), 1), formatNumber(100 * c(k).dRange(2), 1)), ...
        formatNumber(1 - c(k).d, 3), formatNumber(1e3 * c(k).J, 4), m};
end
if result.healthyCompetes || ~result.damageDetected
    if likelihood
        m = formatNumber(result.Shealthy - min(result.evaluated.S), 2);
    else
        m = formatNumber(result.Jhealthy / max(result.best.J, realmin), 3);
        if ~result.damageDetected
            m = formatNumber(1, 3);
        end
    end
    row = {'no damage (healthy)', '-', '0', '-', '1.000', formatNumber(1e3 * result.Jhealthy, 4), m};
    if result.damageDetected
        data(end+1, :) = row;
    else
        data = [row; data];
    end
end
end

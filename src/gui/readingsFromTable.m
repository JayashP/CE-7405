function uObs = readingsFromTable(data, nSensors, nPositions, U)
%READINGSFROMTABLE Observed deflections [m] from the Stage 3 readings table [mm].
%   UOBS = READINGSFROMTABLE(DATA, NSENSORS, NPOSITIONS) checks that DATA
%   (numeric, one row per sensor, one column per truck position, in mm,
%   downward negative; NaN or empty = missing) has the expected size and
%   returns the readings in m. A table of the wrong size (sensors or
%   positions changed after the readings were entered) or with Inf throws
%   'BridgeFE:invalidInput'.
%   UOBS = READINGSFROMTABLE(DATA, NSENSORS, NPOSITIONS, U) reads DATA in
%   U.deflection (display units U of UNITSYSTEM, e.g. in for 'US'); UOBS is
%   still in m.
%
%   See also IDENTIFYSINGLEDAMAGE, UNITSYSTEM.

if nargin < 4 || isempty(U)
    U = unitSystem('SI');
end
if iscell(data)
    data = cellfun(@cellToNumber, data);
end
if ~(isnumeric(data) && isreal(data) && isequal(size(data), [nSensors nPositions]))
    error('BridgeFE:invalidInput', ['The readings table must have %d rows (sensors) and %d columns (truck ' ...
        'positions); press "Generate synthetic readings" or "New empty table" after changing them.'], nSensors, nPositions);
end
if any(isinf(data(:)))
    error('BridgeFE:invalidInput', 'Readings must be finite numbers in %s (leave a cell empty if it is missing).', ...
        U.deflection.unit);
end
perM = 1 / U.deflection.toSI;                % deflection display units per m (1000 for mm, exactly)
uObs = double(data) / perM;
end

function v = cellToNumber(c)
if isnumeric(c) && isscalar(c)
    v = double(c);
elseif isempty(c)
    v = NaN;
else
    v = str2double(c);
end
end

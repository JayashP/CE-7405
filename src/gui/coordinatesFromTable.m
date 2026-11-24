function x = coordinatesFromTable(values, rowLabel, symbol, U)
%COORDINATESFROMTABLE Coordinates typed in a one-column app table, in SI.
%   X = COORDINATESFROMTABLE(VALUES, ROWLABEL, SYMBOL, U) reads the sensor
%   or truck-position table of the Identification tab: VALUES is the
%   table data (a cell column or a numeric vector, one coordinate per row,
%   in U.length), and X is the row vector in metres. Every row must hold a
%   real, finite number; an empty or invalid row throws
%   'BridgeFE:invalidInput' with a message that names it, for example
%   'Sensor 2: x must be a number (m).' or 'Truck position 3: x_v must be a
%   number (ft).' An empty table gives 'Add at least one sensor.'
%   ROWLABEL is the row name in messages ('Sensor', 'Truck position') and
%   SYMBOL the coordinate name ('x', 'x_v'). U defaults to SI.
%
%   Example:
%     x = coordinatesFromTable({5; 10; 15}, 'Sensor', 'x', unitSystem('SI'));   % [5 10 15]
%
%   See also BRIDGECONDITIONAPP, UNITSYSTEM, IDENTIFICATIONDEFAULTS.

if nargin < 4 || isempty(U)
    U = unitSystem('SI');
end
if isempty(values)
    error('BridgeFE:invalidInput', 'Add at least one %s.', lower(rowLabel));
end
if iscell(values)
    v = NaN(1, numel(values));
    for k = 1:numel(values)
        c = values{k};
        if isnumeric(c) && isscalar(c) && isreal(c) && isfinite(c)
            v(k) = double(c);
        end
    end
elseif isnumeric(values) && isreal(values)
    v = double(values(:)');
    v(~isfinite(v)) = NaN;
else
    error('BridgeFE:invalidInput', '%s table must hold numbers (one per row).', rowLabel);
end
bad = find(isnan(v), 1);
if ~isempty(bad)
    error('BridgeFE:invalidInput', '%s %d: %s must be a number (%s).', rowLabel, bad, symbol, U.length.unit);
end
x = v * U.length.toSI;
end

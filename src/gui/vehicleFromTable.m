function vehicle = vehicleFromTable(axleLoads, spacings, name, U)
%VEHICLEFROMTABLE Vehicle from the app's axle table (display units).
%   VEHICLE = VEHICLEFROMTABLE(AXLELOADS, SPACINGS, NAME, U) reads the axle
%   load magnitudes [U.force] (positive = downward, front axle first) and
%   the spacings [U.length] between consecutive axles, front to rear, and
%   returns the SI engine vehicle
%       CREATEVEHICLE(AXLELOADS * U.force.toSI, SPACINGS * U.length.toSI, NAME).
%   SPACINGS(k) is the distance from axle k to axle k+1, so it holds
%   numel(AXLELOADS) - 1 values ([] for a single axle). U is the display
%   unit system (UNITSYSTEM, default SI) and NAME defaults to 'vehicle'.
%   Both lists may be numeric vectors or cell arrays of numbers (table
%   columns). An invalid entry throws 'BridgeFE:invalidVehicle' with a
%   message that names its axle row, for example 'Axle 2: load must be a
%   positive number (kN).' or 'Axle 3: spacing from axle 2 must be a
%   positive number (m).'
%
%   Example (AASHTO HL-93 design-truck axles typed in US customary units):
%     v = vehicleFromTable([8 32 32], [14 14], 'HL-93 axles', unitSystem('US'));
%
%   See also VEHICLEPRESETS, CREATEVEHICLE, VEHICLEFROMINPUTS, UNITSYSTEM.

if nargin < 3 || isempty(name)
    name = 'vehicle';
end
if nargin < 4 || isempty(U)
    U = unitSystem('SI');
end
id = 'BridgeFE:invalidVehicle';
loads = tableNumbers(axleLoads, 'Axle loads');
gaps = tableNumbers(spacings, 'Axle spacings');
n = numel(loads);
if n == 0
    error(id, 'Add at least one axle to the axle table.');
end
for k = 1:n
    if ~(loads(k) > 0)
        error(id, 'Axle %d: load must be a positive number (%s).', k, U.force.unit);
    end
end
if numel(gaps) ~= n - 1
    error(id, 'Give %d spacing(s) for %d axle(s) (from each axle to the next, front to rear); %d given.', ...
        n - 1, n, numel(gaps));
end
for k = 1:n - 1
    if ~(gaps(k) > 0)
        error(id, 'Axle %d: spacing from axle %d must be a positive number (%s).', k + 1, k, U.length.unit);
    end
end
vehicle = createVehicle(loads * U.force.toSI, gaps * U.length.toSI, name);
end

function v = tableNumbers(values, name)
% Row vector of a table column; entries that are not real, finite numbers become NaN.
if isempty(values)
    v = zeros(1, 0);
elseif iscell(values)
    v = NaN(1, numel(values));
    for k = 1:numel(values)
        c = values{k};
        if isnumeric(c) && isscalar(c) && isreal(c) && isfinite(c)
            v(k) = double(c);
        end
    end
elseif isnumeric(values) && isreal(values)
    v = double(values(:).');
    v(~isfinite(v)) = NaN;
else
    error('BridgeFE:invalidVehicle', '%s must be a list of numbers (one per table row).', name);
end
end

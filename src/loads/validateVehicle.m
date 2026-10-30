function validateVehicle(vehicle)
%VALIDATEVEHICLE Check a vehicle struct created by CREATEVEHICLE.
%   VALIDATEVEHICLE(VEHICLE) returns silently for a valid vehicle and
%   otherwise throws 'BridgeFE:invalidVehicle': at least one axle, every
%   axle load a real, finite, positive magnitude [N], one real, finite,
%   positive spacing [m] between each pair of consecutive axles, and a
%   character-vector name.
%
%   See also CREATEVEHICLE.

id = 'BridgeFE:invalidVehicle';
if ~(isstruct(vehicle) && isscalar(vehicle) && isfield(vehicle, 'axleLoads') ...
        && isfield(vehicle, 'axleSpacings') && isfield(vehicle, 'name'))
    error(id, 'vehicle must be a struct with fields name, axleLoads and axleSpacings (use createVehicle).');
end
P = vehicle.axleLoads;
d = vehicle.axleSpacings;
if ~(isnumeric(P) && isreal(P) && isvector(P) && all(isfinite(P)) && all(P > 0))
    error(id, 'axleLoads must be a vector of real, finite, positive magnitudes [N] (positive = downward).');
end
if ~(isnumeric(d) && isreal(d) && numel(d) == numel(P) - 1 && (isempty(d) || isvector(d)) ...
        && all(isfinite(d)) && all(d > 0))
    error(id, 'axleSpacings must hold %d real, finite, positive spacing(s) [m] for %d axle(s).', ...
        numel(P) - 1, numel(P));
end
if ~(ischar(vehicle.name) && (isrow(vehicle.name) || isempty(vehicle.name)))
    error(id, 'vehicle name must be a character vector.');
end
end

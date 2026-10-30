function vehicle = createVehicle(axleLoads, axleSpacings, name)
%CREATEVEHICLE Define a multi-axle vehicle for quasi-static moving-load analysis.
%   VEHICLE = CREATEVEHICLE(AXLELOADS, AXLESPACINGS, NAME) returns a vehicle
%   struct (DECISIONS.md D-019):
%     AXLELOADS     N-by-1 axle load MAGNITUDES [N], positive = downward,
%                   listed from the front (axle 1) to the rear axle
%     AXLESPACINGS  (N-1)-by-1 distances [m] between consecutive axles, front
%                   to rear ([] for a single axle)
%     NAME          optional label, default 'vehicle'
%   The reference axle is the FRONT axle: at vehicle position x_v, axle i is
%   at x_v - direction*(sum of spacings ahead of it) (VEHICLEAXLEPOSITIONS).
%   The magnitudes are turned into downward (negative) forces only when
%   they are applied to the beam.
%
%   Example (illustrative 3-axle truck of PROJECT_SPEC.md section 5.1; not an
%   AASHTO design truck):
%     truck = createVehicle([80e3 120e3 120e3], [4.2 1.4], '3-axle example');
%
%   See also VALIDATEVEHICLE, VEHICLEAXLEPOSITIONS, GENERATEVEHICLEPOSITIONS,
%   RUNMOVINGLOAD.

if nargin < 3
    name = 'vehicle';
end
if isa(name, 'string') && isscalar(name)
    name = char(name);
end
vehicle.name = name;
vehicle.axleLoads = axleLoads;
vehicle.axleSpacings = axleSpacings;
validateVehicle(vehicle);
vehicle.axleLoads = double(axleLoads(:));
vehicle.axleSpacings = double(reshape(axleSpacings, [], 1));
vehicle.reference = 'front axle (axle 1)';
vehicle.units = struct('axleLoads', 'N (magnitude, positive downward)', 'axleSpacings', 'm');
end

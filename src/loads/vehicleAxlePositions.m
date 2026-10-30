function [x, P] = vehicleAxlePositions(vehicle, xv, direction)
%VEHICLEAXLEPOSITIONS Axle coordinates and signed axle forces at a vehicle position.
%   [X, P] = VEHICLEAXLEPOSITIONS(VEHICLE, XV, DIRECTION) returns, for the
%   vehicle position XV [m] = coordinate of the FRONT axle, the N-by-1 axle
%   coordinates X [m] and the signed axle forces P [N] (negative = downward,
%   DECISIONS.md D-003). DIRECTION is +1 (travel toward +x, the default) or
%   -1 (travel toward -x); the rear axles trail behind the front axle:
%       X = XV - DIRECTION * [0; cumsum(axleSpacings)]
%   Axles may lie off the beam; RUNMOVINGLOAD and ANALYZEVEHICLEPOSITION
%   apply only the axles on it.
%
%   Example (3-axle truck with its front axle at 10 m, moving toward +x):
%     [x, P] = vehicleAxlePositions(truck, 10)    % x = [10; 5.8; 4.4]
%
%   See also CREATEVEHICLE, GENERATEVEHICLEPOSITIONS.

if nargin < 3
    direction = 1;
end
validateVehicle(vehicle);
assertFiniteRealScalar(xv, 'xv');
if ~(isnumeric(direction) && isscalar(direction) && (direction == 1 || direction == -1))
    error('BridgeFE:invalidInput', 'direction must be +1 (toward +x) or -1 (toward -x).');
end

offsets = [0; cumsum(vehicle.axleSpacings(:))];
x = xv - direction * offsets;
P = -vehicle.axleLoads(:);
end

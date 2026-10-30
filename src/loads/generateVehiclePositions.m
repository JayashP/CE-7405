function [xv, step] = generateVehiclePositions(model, vehicle, step, direction)
%GENERATEVEHICLEPOSITIONS Front-axle positions that move a vehicle across the whole beam.
%   [XV, STEP] = GENERATEVEHICLEPOSITIONS(MODEL, VEHICLE, STEP, DIRECTION)
%   returns the column of front-axle positions XV [m] for a crossing
%   (DECISIONS.md D-019):
%     DIRECTION = +1 (default): from XV = x_1 (front axle at the left end,
%       every other axle still off the beam) to XV = x_n + vehicle length
%       (rear axle at the right end).
%     DIRECTION = -1: from XV = x_n down to XV = x_1 - vehicle length.
%   The positions are equally spaced. The returned STEP is the actual
%   spacing, the largest value <= the requested STEP that divides the
%   travel distance into whole steps. An axle exactly at an end support
%   only loads that reaction (DECISIONS.md D-017).
%
%   Example:
%     [xv, h] = generateVehiclePositions(model, truck, 0.1);
%
%   See also VEHICLEAXLEPOSITIONS, RUNMOVINGLOAD.

if nargin < 4
    direction = 1;
end
validateModel(model);
validateVehicle(vehicle);
assertPositiveFiniteScalar(step, 'step');
if ~(isnumeric(direction) && isscalar(direction) && (direction == 1 || direction == -1))
    error('BridgeFE:invalidInput', 'direction must be +1 (toward +x) or -1 (toward -x).');
end

x = model.nodes.x;
vehicleLength = sum(vehicle.axleSpacings);
if direction == 1
    xStart = x(1);
    xEnd = x(end) + vehicleLength;
else
    xStart = x(end);
    xEnd = x(1) - vehicleLength;
end
travel = abs(xEnd - xStart);
n = max(1, ceil(travel / step - 1e-9));
xv = xStart + (xEnd - xStart) * ((0:n)' / n);
step = travel / n;
end

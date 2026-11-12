function [sensorX, positions] = identificationDefaults(model, vehicle, direction)
%IDENTIFICATIONDEFAULTS Default sensors and truck positions for the Stage 3 tab.
%   [SENSORX, POSITIONS] = IDENTIFICATIONDEFAULTS(MODEL, VEHICLE, DIRECTION)
%   returns sensors at L/4, L/2 and 3L/4 of the beam length L and
%   front-axle positions L/4, L/2, 3L/4, L and 5L/4 from the entry end
%   (the left end for DIRECTION = +1, the right end for -1), rounded to
%   1 mm. With a VEHICLE, positions and sensors whose healthy predicted
%   readings are all zero are left out: a position with no axle on the
%   beam (or only on supports) and a sensor on a support would give zero
%   readings, which carry no information and have no proportional noise. For a 20 m span and the spec
%   3-axle truck this is PROJECT_SPEC.md section 7: sensors at 5, 10, 15 m,
%   positions 5, 10, 15, 20, 25 m. Without VEHICLE (or empty) no position
%   is left out. Both can be changed in the app.
%
%   See also IDENTIFYSINGLEDAMAGE, BRIDGECONDITIONAPP.

if nargin < 2
    vehicle = [];
end
if nargin < 3
    direction = 1;
end
validateModel(model);
x = model.nodes.x;
L = x(end) - x(1);
sensorX = round((x(1) + L * [0.25 0.5 0.75]) * 1000) / 1000;
offset = L * (0.25:0.25:1.25);
if direction == 1
    positions = x(1) + offset;
else
    positions = x(end) - offset;
end
positions = round(positions * 1000) / 1000;
if ~isempty(vehicle)
    % A position with no axle on the beam (or only on supports) and a sensor on a support
    % give all-zero healthy readings: both are left out.
    uH = predictSensorDeflections(model, vehicle, positions, sensorX, direction);
    small = 1e-12 * max(abs(uH(:)));
    positions = positions(max(abs(uH), [], 1) > small);
    sensorX = sensorX(max(abs(uH), [], 2)' > small);
end
end

function u = predictSensorDeflections(model, vehicle, xvList, sensorX, direction)
%PREDICTSENSORDEFLECTIONS Vehicle-induced deflections at sensors for known vehicle positions (Stage 3).
%   U = PREDICTSENSORDEFLECTIONS(MODEL, VEHICLE, XVLIST, SENSORX, DIRECTION)
%   returns the NS-by-NP matrix of deflections [m] (+ up, so downward
%   deflections are negative) at the NS sensor coordinates SENSORX [m]
%   caused by VEHICLE with its front axle at each of the NP positions XVLIST
%   [m] (DIRECTION +1, default, or -1). U(i, p) is sensor i, position p.
%
%   The value is the deflection caused by the VEHICLE ONLY: the response to
%   the model's permanent loads (if any) is subtracted, because a measured
%   live-load deflection is taken relative to the unloaded bridge
%   (DECISIONS.md D-028). It uses the verified moving-load engine
%   (PREPAREMOVINGLOAD with the sensors as stations, ANALYZEVEHICLEPOSITION):
%   exact Hermite + particular-solution deflection at sensors between nodes,
%   effective EI = (1 - d) EI of any damaged element, axles off the beam
%   ignored. A sensor outside the beam throws 'BridgeFE:offBeam'.
%
%   Example (spec section 7: sensors at L/4, L/2, 3L/4; 5 truck positions):
%     u = predictSensorDeflections(model, truck, [5 10 15 20 25], [5 10 15]);
%
%   See also IDENTIFYSINGLEDAMAGE, ANALYZEVEHICLEPOSITION, EVALUATEDEFLECTION.

if nargin < 5
    direction = 1;
end
validateModel(model);
validateVehicle(vehicle);
x = model.nodes.x;
L = x(end) - x(1);
tol = 1e-9 * L;
if ~(isnumeric(sensorX) && isreal(sensorX) && isvector(sensorX) && all(isfinite(sensorX)))
    error('BridgeFE:invalidInput', 'Sensor coordinates must be a real, finite vector [m].');
end
if any(sensorX < x(1) - tol | sensorX > x(end) + tol)
    error('BridgeFE:offBeam', 'Sensor coordinates must lie on the beam (%g to %g m).', x(1), x(end));
end
if ~(isnumeric(xvList) && isreal(xvList) && isvector(xvList) && all(isfinite(xvList)))
    error('BridgeFE:invalidInput', 'Vehicle positions must be a real, finite vector [m].');
end
if ~(isequal(direction, 1) || isequal(direction, -1))
    error('BridgeFE:invalidInput', 'Direction must be +1 or -1.');
end
sensorX = min(max(double(sensorX(:)), x(1)), x(end));
prep = prepareMovingLoad(model, sensorX);
% Permanent-load response: the vehicle placed completely off the beam.
offBeam = x(1) - 1 - sum(vehicle.axleSpacings);
if direction == -1
    offBeam = x(end) + 1 + sum(vehicle.axleSpacings);
end
base = analyzeVehiclePosition(prep, vehicle, offBeam, direction);
u = zeros(numel(sensorX), numel(xvList));
for p = 1:numel(xvList)
    res = analyzeVehiclePosition(prep, vehicle, xvList(p), direction);
    u(:, p) = res.stations.v(:) - base.stations.v(:);
end
end

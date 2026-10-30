function model = modelWithVehicle(model, vehicle, xv, direction)
%MODELWITHVEHICLE Static model with the vehicle's on-bridge axles added as point loads.
%   MODEL = MODELWITHVEHICLE(MODEL, VEHICLE, XV, DIRECTION) adds the axles of
%   VEHICLE (front axle at XV [m], DIRECTION +1 or -1, default +1) that lie
%   on the beam as point loads (ADDPOINTLOAD), using the same on-bridge rule
%   as ANALYZEVEHICLEPOSITION (1e-9 times the beam length). Solving the result
%   with SOLVESTATICMODEL reproduces that vehicle position through the
%   verified static path. The app uses it to show K, F, U and R.
%
%   See also ANALYZEVEHICLEPOSITION, SOLVESTATICMODEL, VEHICLEAXLEPOSITIONS.

if nargin < 4
    direction = 1;
end
validateModel(model);
[xa, Pa] = vehicleAxlePositions(vehicle, xv, direction);
x = model.nodes.x;
tol = 1e-9 * (x(end) - x(1));
for k = 1:numel(xa)
    if xa(k) >= x(1) - tol && xa(k) <= x(end) + tol
        model = addPointLoad(model, min(max(xa(k), x(1)), x(end)), Pa(k));
    end
end
end

function vehicle = vehicleFromInputs(axleLoads_kN, spacings_m, name)
%VEHICLEFROMINPUTS Vehicle from the app's inputs (axle loads in kN, spacings in m).
%   VEHICLE = VEHICLEFROMINPUTS(AXLELOADS_KN, SPACINGS_M, NAME) reads the
%   axle load magnitudes [kN] (positive = downward, front axle first) and
%   the spacings [m] between consecutive axles (front to rear), given as
%   numbers or text such as '80 120 120' and '4.2 1.4', and returns
%   CREATEVEHICLE(loads*1e3, spacings, NAME). A single axle may leave the
%   spacings empty.
%
%   See also CREATEVEHICLE, PARSENUMBERLIST.

if nargin < 3 || isempty(name)
    name = 'vehicle';
end
loads = parseNumberList(axleLoads_kN, 'Axle loads');
if isa(spacings_m, 'string') && isscalar(spacings_m)
    spacings_m = char(spacings_m);
end
if numel(loads) == 1 && (isempty(spacings_m) || (ischar(spacings_m) && isempty(strtrim(spacings_m))))
    spacings = [];
else
    spacings = parseNumberList(spacings_m, 'Axle spacings');
end
vehicle = createVehicle(loads * 1e3, spacings, name);
end

function presets = vehiclePresets(U)
%VEHICLEPRESETS Vehicles offered in the app's vehicle drop-down, in display units.
%   PRESETS = VEHICLEPRESETS(U) returns a 3-by-1 struct array with fields
%     name      text for the drop-down
%     loads     axle load magnitudes [U.force], front axle first (row)
%     spacings  distances between consecutive axles [U.length], front to
%               rear (row)
%     note      what the preset represents and what it leaves out
%   in the display units U (UNITSYSTEM, default SI):
%     1  'Illustrative 3-axle truck (spec)': 80, 120, 120 kN; 4.2, 1.4 m.
%        The example truck of PROJECT_SPEC.md section 5.1, not an AASHTO
%        design truck.
%     2  'AASHTO HL-93 design truck (axles only)': 8, 32, 32 kip; 14, 14 ft.
%        The rear spacing is variable 14-30 ft in AASHTO LRFD 3.6.1.2.2;
%        14 ft is used. Axle loads only: no design lane load and no
%        dynamic load allowance.
%     3  'Custom': no axles (empty loads and spacings); the app keeps the
%        axles already typed in its table.
%   Each preset is stored in the unit system it is defined in (preset 1
%   SI, preset 2 US customary): in that system the values are returned as
%   typed above, and in the other one they are converted with the exact
%   factors of UNITSYSTEM, without rounding. VEHICLEFROMTABLE with the
%   same U gives the engine vehicle.
%
%   Example (HL-93 axles in SI: 35.5858, 142.343, 142.343 kN; 4.2672 m):
%     U = unitSystem('SI');
%     p = vehiclePresets(U);
%     truck = vehicleFromTable(p(2).loads, p(2).spacings, p(2).name, U);
%
%   See also VEHICLEFROMTABLE, UNITSYSTEM, CREATEVEHICLE.

if nargin < 1 || isempty(U)
    U = unitSystem('SI');
end
SI = unitSystem('SI');
US = unitSystem('US');
presets = [ ...
    preset('Illustrative 3-axle truck (spec)', [80 120 120], [4.2 1.4], SI, U, ...
        'Illustrative 3-axle truck of PROJECT_SPEC.md section 5.1; not an AASHTO design truck.'); ...
    preset('AASHTO HL-93 design truck (axles only)', [8 32 32], [14 14], US, U, ...
        ['Axle loads only: no design lane load, no dynamic load allowance. The rear spacing is ' ...
         'variable 14-30 ft in AASHTO LRFD 3.6.1.2.2; 14 ft is used.']); ...
    struct('name', 'Custom', 'loads', zeros(1, 0), 'spacings', zeros(1, 0), ...
        'note', 'Your own axles: the table keeps the loads and spacings typed in it.')];
end

function p = preset(name, loads, spacings, defined, U, note)
% Values as typed in the system they are defined in; exact conversion otherwise.
if ~strcmp(defined.name, U.name)
    loads = loads * defined.force.toSI / U.force.toSI;
    spacings = spacings * defined.length.toSI / U.length.toSI;
end
p = struct('name', name, 'loads', loads, 'spacings', spacings, 'note', note);
end

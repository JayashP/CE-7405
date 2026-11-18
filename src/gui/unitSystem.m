function U = unitSystem(name)
%UNITSYSTEM Display units of the app: SI or US customary, with exact factors to SI.
%   U = UNITSYSTEM(NAME) for NAME = 'SI' (default) or 'US' returns the
%   units in which the app shows every input and result (DECISIONS.md
%   D-031). The engine always works in SI (m, N, Pa); U only converts at
%   the app's edges:
%       value_SI      = value_display * U.(kind).toSI
%       value_display = value_SI / U.(kind).toSI
%   U fields:
%     name    'SI' or 'US'
%     label   text for the unit-system drop-down
%     and one struct (unit text, toSI factor) per kind of quantity:
%       kind          SI              US customary
%       length        m               ft      (0.3048 m, exact)
%       deflection    mm              in      (0.0254 m, exact)
%       force         kN              kip     (4448.2216152605 N, exact)
%       moment        kN*m            kip*ft
%       distributed   kN/m            kip/ft
%       modulus       GPa             ksi     (kip/in^2 = 6894757.293 Pa)
%       inertia       m^4             in^4
%   Factors follow NIST SP 811 (international foot and inch, avoirdupois
%   pound-force with standard gravity 9.80665 m/s^2).
%
%   Example (a 50 ft span typed in US units, in metres for the engine):
%     U = unitSystem('US');
%     L = 50 * U.length.toSI;          % 15.24 m
%
%   See also BRIDGECONDITIONAPP.

if nargin < 1 || isempty(name)
    name = 'SI';
end
if isa(name, 'string') && isscalar(name)
    name = char(name);
end
ft = 0.3048;
inch = 0.0254;
kip = 4448.2216152605;          % 1000 lbf
ksi = kip / inch^2;             % 1000 lbf/in^2 = 6894757.293... Pa
switch upper(name)
    case 'SI'
        U.name = 'SI';
        U.label = 'SI (m, kN, GPa)';
        U.length = unit('m', 1);
        U.deflection = unit('mm', 1e-3);
        U.force = unit('kN', 1e3);
        U.moment = unit('kN*m', 1e3);
        U.distributed = unit('kN/m', 1e3);
        U.modulus = unit('GPa', 1e9);
        U.inertia = unit('m^4', 1);
    case 'US'
        U.name = 'US';
        U.label = 'US customary (ft, kip, ksi)';
        U.length = unit('ft', ft);
        U.deflection = unit('in', inch);
        U.force = unit('kip', kip);
        U.moment = unit('kip*ft', kip * ft);
        U.distributed = unit('kip/ft', kip / ft);
        U.modulus = unit('ksi', ksi);
        U.inertia = unit('in^4', inch^4);
    otherwise
        error('BridgeFE:invalidInput', 'Unknown unit system ''%s''. Use ''SI'' or ''US''.', char(name));
end
end

function u = unit(text, toSI)
u = struct('unit', text, 'toSI', toSI);
end

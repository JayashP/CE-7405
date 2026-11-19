function [q, extraDecimals] = quantityDisplay(code, U)
%QUANTITYDISPLAY Label, unit and SI-to-display scale for a response quantity code.
%   Q = QUANTITYDISPLAY(CODE) for CODE = 'M', 'V', 'v' or 'R' (also the
%   first letter of 'Mmax', 'vmin', 'Rmax', ...) returns Q.label, Q.unit and
%   Q.scale (display value = SI value * Q.scale): kN*m, kN, mm and kN.
%   Q = QUANTITYDISPLAY(CODE, U) uses the display units U of UNITSYSTEM
%   (default SI): M in U.moment, V and R in U.force, v in U.deflection, with
%   Q.unit the unit text and Q.scale = 1 / toSI (kip*ft, kip, in and kip for
%   unitSystem('US')).
%   [Q, EXTRADECIMALS] = QUANTITYDISPLAY(...) also returns the unit's
%   extraDecimals (1 for inches, else 0): tables add it to their SI number
%   of decimals, so inches keep about the resolution of millimetres.
%
%   See also UNITSYSTEM, DAMAGECOMPARISONTABLEDATA, SENSITIVITYTABLEDATA.

if nargin < 2 || isempty(U)
    U = unitSystem('SI');
end
switch code(1)
    case 'M'
        u = U.moment;
        q = displayOf('Moment M', u);
    case 'V'
        u = U.force;
        q = displayOf('Shear V', u);
    case 'v'
        u = U.deflection;
        q = displayOf('Deflection v', u);
    case 'R'
        u = U.force;
        q = displayOf('Reaction R', u);
    otherwise
        error('BridgeFE:invalidInput', 'Unknown quantity code ''%s''.', code);
end
extraDecimals = 0;
if isfield(u, 'extraDecimals')
    extraDecimals = u.extraDecimals;
end
end

function q = displayOf(label, u)
q = struct('label', label, 'unit', u.unit, 'scale', 1 / u.toSI);   % SI: 1e-3 (kN, kN*m) and 1e3 (mm) exactly
end

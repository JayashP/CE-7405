function q = quantityDisplay(code)
%QUANTITYDISPLAY Label, unit and SI-to-display scale for a response quantity code.
%   Q = QUANTITYDISPLAY(CODE) for CODE = 'M', 'V', 'v' or 'R' (also the
%   first letter of 'Mmax', 'vmin', 'Rmax', ...) returns Q.label, Q.unit and
%   Q.scale (display value = SI value * Q.scale): kN*m, kN, mm and kN.
%
%   See also DAMAGECOMPARISONTABLEDATA, SENSITIVITYTABLEDATA.

switch code(1)
    case 'M'
        q = struct('label', 'Moment M', 'unit', 'kN*m', 'scale', 1e-3);
    case 'V'
        q = struct('label', 'Shear V', 'unit', 'kN', 'scale', 1e-3);
    case 'v'
        q = struct('label', 'Deflection v', 'unit', 'mm', 'scale', 1e3);
    case 'R'
        q = struct('label', 'Reaction R', 'unit', 'kN', 'scale', 1e-3);
    otherwise
        error('BridgeFE:invalidInput', 'Unknown quantity code ''%s''.', code);
end
end

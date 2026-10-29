function restraint = supportRestraint(type)
%SUPPORTRESTRAINT Restraint flags [v theta] of an idealized support type.
%   R = SUPPORTRESTRAINT(TYPE) returns a 1-by-2 logical row
%   [restrainV restrainTheta] for a case-insensitive TYPE:
%     'pin'     [true false]
%     'roller'  [true false]  identical to 'pin' here: the bending-only
%                             model has no axial DOF, so horizontal
%                             restraint cannot be represented
%     'fixed'   [true true]
%   An unknown TYPE throws 'BridgeFE:invalidSupportType'.
%
%   See also ADDSUPPORT.

if isa(type, 'string') && isscalar(type)
    type = char(type);
end
if ~(ischar(type) && (isrow(type) || isempty(type)))
    error('BridgeFE:invalidSupportType', ...
        'Support type must be a character vector: ''pin'', ''roller'' or ''fixed''.');
end

switch lower(type)
    case {'pin', 'roller'}
        restraint = [true, false];
    case 'fixed'
        restraint = [true, true];
    otherwise
        error('BridgeFE:invalidSupportType', ...
            'Unknown support type ''%s''. Use ''pin'', ''roller'' or ''fixed''.', type);
end
end

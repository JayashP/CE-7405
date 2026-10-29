function assertFiniteRealScalar(value, name)
%ASSERTFINITEREALSCALAR Error unless VALUE is a real, finite numeric scalar (any sign).
%   ASSERTFINITEREALSCALAR(VALUE, NAME) returns silently for a valid VALUE
%   and otherwise throws 'BridgeFE:invalidInput' naming the argument NAME.

if ~(isnumeric(value) && isscalar(value) && isreal(value) && isfinite(value))
    error('BridgeFE:invalidInput', ...
        '%s must be a real, finite numeric scalar.', name);
end
end

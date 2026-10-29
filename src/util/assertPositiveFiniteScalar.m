function assertPositiveFiniteScalar(value, name)
%ASSERTPOSITIVEFINITESCALAR Error unless VALUE is a real, finite, positive numeric scalar.
%   ASSERTPOSITIVEFINITESCALAR(VALUE, NAME) returns silently for a valid
%   VALUE and otherwise throws 'BridgeFE:invalidInput' with a message that
%   names the argument NAME.

if ~(isnumeric(value) && isscalar(value) && isreal(value) && isfinite(value) && value > 0)
    error('BridgeFE:invalidInput', ...
        '%s must be a real, finite, positive numeric scalar.', name);
end
end

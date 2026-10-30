function mockCheckColor(value, name)
%MOCKCHECKCOLOR Error unless VALUE is an RGB triplet in [0, 1] or a colour name (mock checks only).
if ischar(value)
    return
end
if ~(isnumeric(value) && isequal(size(value), [1 3]) && all(value >= 0 & value <= 1))
    error('Mock:color', '%s must be an RGB triplet in [0, 1].', name);
end
end

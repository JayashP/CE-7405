classdef MockSpinner < MockComponent
    %MOCKSPINNER Stand-in for uispinner; Value must lie within Limits.
    properties
        Value = 0
        Limits = [-Inf Inf]
        Step = 1
        RoundFractionalValues = 'off'
        ValueChangedFcn = []
        ValueChangingFcn = []
        ValueDisplayFormat = '%11.4g'
        LowerLimitInclusive = 'on'
        UpperLimitInclusive = 'on'
        Editable = 'on'
        HorizontalAlignment = 'right'
    end
    methods
        function obj = MockSpinner(parent, args)
            obj@MockComponent('uispinner', parent, args);
        end
        function set.Limits(obj, lim)
            if ~(isnumeric(lim) && numel(lim) == 2 && lim(1) <= lim(2))
                error('Mock:value', 'spinner Limits must be [low high] with low <= high.');
            end
            obj.Limits = lim;
            obj.Value = min(max(obj.Value, lim(1)), lim(2));
        end
        function set.Value(obj, v)
            if ~(isnumeric(v) && isscalar(v) && v >= obj.Limits(1) && v <= obj.Limits(2))
                error('Mock:value', 'spinner Value must be a scalar within Limits.');
            end
            obj.Value = v;
        end
    end
end

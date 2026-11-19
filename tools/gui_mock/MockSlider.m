classdef MockSlider < MockComponent
    %MOCKSLIDER Stand-in for uislider; Limits must increase and Value lie within them.
    properties
        Value = 0
        Limits = [0 100]
        ValueChangedFcn = []
        ValueChangingFcn = []
        MajorTicks = []
        MajorTickLabels = {}
        MinorTicks = []
        Orientation = 'horizontal'
    end
    methods
        function obj = MockSlider(parent, args)
            obj@MockComponent('uislider', parent, args);
        end
        function set.Limits(obj, lim)
            if ~(isnumeric(lim) && numel(lim) == 2 && all(isfinite(lim)) && lim(1) < lim(2))
                error('Mock:value', 'slider Limits must be finite and increasing.');
            end
            obj.Limits = lim;
            obj.Value = min(max(obj.Value, lim(1)), lim(2));   % MATLAB keeps Value inside new Limits
        end
        function set.MajorTicks(obj, t)
            if ~(isnumeric(t) && all(isfinite(t)) && all(diff(t) > 0))
                error('Mock:value', 'slider MajorTicks must be finite and increasing.');
            end
            if any(t < obj.Limits(1) | t > obj.Limits(2))   % strict: a tick outside Limits may not be shown
                error('Mock:value', 'slider MajorTicks must lie within Limits.');
            end
            obj.MajorTicks = t;
        end
        function set.Value(obj, v)
            if ~(isnumeric(v) && isscalar(v) && isfinite(v) && v >= obj.Limits(1) && v <= obj.Limits(2))
                error('Mock:value', 'slider Value must be a finite scalar within Limits.');
            end
            obj.Value = v;
        end
    end
end

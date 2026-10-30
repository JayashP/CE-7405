classdef MockCheckBox < MockComponent
    %MOCKCHECKBOX Stand-in for uicheckbox (GNU Octave app check only; generated from one property table).
    properties
        Text = 'Check Box'
        Value = false
        ValueChangedFcn = []
        WordWrap = 'off'
    end
    methods
        function obj = MockCheckBox(parent, args)
            obj@MockComponent('uicheckbox', parent, args);
        end
        function set.Value(obj, v)
            if ~((islogical(v) || isnumeric(v)) && isscalar(v) && any(v == [0 1]))
                error('Mock:value', 'uicheckbox Value must be true or false.');
            end
            obj.Value = logical(v);
        end
    end
end

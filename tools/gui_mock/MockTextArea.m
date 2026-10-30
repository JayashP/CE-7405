classdef MockTextArea < MockComponent
    %MOCKTEXTAREA Stand-in for uitextarea (GNU Octave app check only; generated from one property table).
    properties
        Value = {''}
        Editable = 'on'
        HorizontalAlignment = 'left'
        WordWrap = 'on'
        Placeholder = ''
    end
    methods
        function obj = MockTextArea(parent, args)
            obj@MockComponent('uitextarea', parent, args);
        end
        function set.Value(obj, v)
            if ~(ischar(v) || iscellstr(v))
                error('Mock:value', 'uitextarea Value must be a character vector or cell array of them.');
            end
            obj.Value = v;
        end
    end
end

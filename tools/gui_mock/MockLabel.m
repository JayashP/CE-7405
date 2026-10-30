classdef MockLabel < MockComponent
    %MOCKLABEL Stand-in for uilabel (GNU Octave app check only; generated from one property table).
    properties
        Text = 'Label'
        HorizontalAlignment = 'left'
        VerticalAlignment = 'center'
        WordWrap = 'off'
        Interpreter = 'none'
    end
    methods
        function obj = MockLabel(parent, args)
            obj@MockComponent('uilabel', parent, args);
        end
        function set.Text(obj, v)
            if ~(ischar(v) || iscellstr(v))
                error('Mock:value', 'uilabel Text must be text.');
            end
            obj.Text = v;
        end
    end
end

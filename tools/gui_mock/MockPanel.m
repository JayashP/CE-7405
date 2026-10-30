classdef MockPanel < MockComponent
    %MOCKPANEL Stand-in for uipanel (GNU Octave app check only; generated from one property table).
    properties
        Title = ''
        ForegroundColor = [0 0 0]
        BorderType = 'line'
        TitlePosition = 'lefttop'
        Scrollable = 'off'
        BorderWidth = 1
    end
    methods
        function obj = MockPanel(parent, args)
            obj@MockComponent('uipanel', parent, args);
        end
        function set.ForegroundColor(obj, v)
            mockCheckColor(v, 'uipanel.ForegroundColor');
            obj.ForegroundColor = v;
        end
    end
end

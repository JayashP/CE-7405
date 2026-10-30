classdef MockFigure < MockComponent
    %MOCKFIGURE Stand-in for uifigure (GNU Octave app check only; generated from one property table).
    properties
        Name = ''
        Color = [0.94 0.94 0.94]
        CloseRequestFcn = []
        Pointer = 'arrow'
        Scrollable = 'off'
        WindowStyle = 'normal'
        Icon = ''
        AutoResizeChildren = 'on'
        Resize = 'on'
        Alerts = {}
    end
    methods
        function obj = MockFigure(parent, args)
            obj@MockComponent('uifigure', parent, args);
        end
        function set.Color(obj, v)
            mockCheckColor(v, 'uifigure.Color');
            obj.Color = v;
        end
    end
end

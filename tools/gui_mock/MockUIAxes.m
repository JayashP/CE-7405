classdef MockUIAxes < MockComponent
    %MOCKUIAXES Stand-in for uiaxes (GNU Octave app check only; generated from one property table).
    properties
        XLim = [0 1]
        YLim = [0 1]
        XTick = []
        YTick = []
        Color = [1 1 1]
        Box = 'off'
        XGrid = 'off'
        YGrid = 'off'
        NextPlot = 'replace'
        DataAspectRatio = [1 1 1]
        Title = ''
        XLabel = ''
        YLabel = ''
        Legend = []          % like MATLAB: [] or a legend with a String property (cell of labels)
    end
    methods
        function obj = MockUIAxes(parent, args)
            obj@MockComponent('uiaxes', parent, args);
        end
        function set.Color(obj, v)
            mockCheckColor(v, 'uiaxes.Color');
            obj.Color = v;
        end
    end
end

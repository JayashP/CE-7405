classdef MockTabGroup < MockComponent
    %MOCKTABGROUP Stand-in for uitabgroup (GNU Octave app check only; generated from one property table).
    properties
        SelectionChangedFcn = []
        SelectedTab = []
        TabLocation = 'top'
    end
    methods
        function obj = MockTabGroup(parent, args)
            obj@MockComponent('uitabgroup', parent, args);
        end
    end
end

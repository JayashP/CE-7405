classdef MockGridLayout < MockComponent
    %MOCKGRIDLAYOUT Stand-in for uigridlayout (GNU Octave app check only; generated from one property table).
    properties
        RowHeight = {'1x', '1x'}
        ColumnWidth = {'1x', '1x'}
        Padding = [10 10 10 10]
        RowSpacing = 10
        ColumnSpacing = 10
        Scrollable = 'off'
    end
    methods
        function obj = MockGridLayout(parent, args)
            obj@MockComponent('uigridlayout', parent, args);
        end
    end
end

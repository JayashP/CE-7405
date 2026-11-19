classdef MockTable < MockComponent
    %MOCKTABLE Stand-in for uitable (GNU Octave app check only; generated from one property table).
    properties
        Data = []
        ColumnName = 'numbered'
        RowName = 'numbered'
        ColumnWidth = 'auto'
        ColumnEditable = []
        ColumnFormat = {}
        ColumnSortable = []
        RowStriping = 'on'
        CellEditCallback = []
        Selection = []
    end
    methods
        function obj = MockTable(parent, args)
            obj@MockComponent('uitable', parent, args);
        end
        function set.Data(obj, v)
            if ~(iscell(v) || isnumeric(v) || islogical(v))
                error('Mock:value', 'uitable Data must be a cell array, numeric or logical array.');
            end
            obj.Data = v;
        end
        function set.ColumnName(obj, v)
            if ~(ischar(v) || iscellstr(v))
                error('Mock:value', 'uitable ColumnName must be text or a cell array of text.');
            end
            if iscell(v) && ~isempty(v)
                v = v(:);                               % MATLAB stores a 1-by-n cell array as n-by-1
            end
            obj.ColumnName = v;
        end
        function set.RowName(obj, v)
            if ~(ischar(v) || iscellstr(v))
                error('Mock:value', 'uitable RowName must be text or a cell array of text.');
            end
            if iscell(v) && ~isempty(v)
                v = v(:);                               % as MATLAB stores it
            end
            obj.RowName = v;
        end
    end
end

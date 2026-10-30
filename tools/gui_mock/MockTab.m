classdef MockTab < MockComponent
    %MOCKTAB Stand-in for uitab (GNU Octave app check only; generated from one property table).
    properties
        Title = ''
        ForegroundColor = [0 0 0]
        Scrollable = 'off'
    end
    methods
        function obj = MockTab(parent, args)
            obj@MockComponent('uitab', parent, args);
        end
        function set.ForegroundColor(obj, v)
            mockCheckColor(v, 'uitab.ForegroundColor');
            obj.ForegroundColor = v;
        end
        function set.Title(obj, v)
            if ~ischar(v)
                error('Mock:value', 'uitab Title must be a character vector.');
            end
            obj.Title = v;
        end
    end
end

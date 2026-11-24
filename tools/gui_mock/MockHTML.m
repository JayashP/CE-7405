classdef MockHTML < MockComponent
    %MOCKHTML Stand-in for uihtml (GNU Octave app check only). Stores the HTML text it is given.
    %   MATLAB renders HTMLSource; the stand-in only checks that it is one
    %   complete HTML document in a character row vector.
    properties
        HTMLSource = ''
        Data = []
        DataChangedFcn = []
        HTMLEventReceivedFcn = []
    end
    methods
        function obj = MockHTML(parent, args)
            obj@MockComponent('uihtml', parent, args);
        end
        function set.HTMLSource(obj, v)
            if ~(ischar(v) && (isrow(v) || isempty(v)))
                error('Mock:value', 'uihtml HTMLSource must be a character row vector.');
            end
            if ~isempty(v) && isempty(strfind(v, '</html>'))
                error('Mock:value', 'uihtml HTMLSource must be a complete HTML document.');
            end
            obj.HTMLSource = v;
        end
    end
end

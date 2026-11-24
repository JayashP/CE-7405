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
        function applyArgs(obj, args)
            % MATLAB's uihtml has no visual properties (BackgroundColor, FontColor, FontSize, Tooltip, Enable):
            % the stand-in refuses them here and, when set later, in MockComponent's set methods, so such an
            % edit cannot pass here and fail in MATLAB.
            allowed = {'HTMLSource', 'Data', 'DataChangedFcn', 'HTMLEventReceivedFcn', 'Visible', 'Layout', ...
                'Position', 'Tag', 'UserData'};
            for k = 1:2:numel(args)
                if ~(ischar(args{k}) && any(strcmp(args{k}, allowed)))
                    error('Mock:unknownProperty', 'uihtml has no settable property ''%s''.', num2str(args{k}));
                end
            end
            applyArgs@MockComponent(obj, args);
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

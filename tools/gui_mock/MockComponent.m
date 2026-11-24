classdef MockComponent < handle
    %MOCKCOMPONENT Stand-in for a MATLAB UI component, used only to run the app in GNU Octave.
    %   Octave has no App Designer components. The Mock* classes in
    %   tools/gui_mock list the properties of the real components, so that
    %   running BridgeConditionApp against them catches unknown property
    %   names, Layout set outside a grid, invalid colours and out-of-range
    %   values before the app is opened in MATLAB. They draw nothing.
    %   See tools/gui_mock/runGuiMockCheck.m.
    properties
        Type = ''
        Parent = []
        Children = {}
        Layout = struct('Row', [], 'Column', [])
        Visible = 'on'
        Enable = 'on'
        Tag = ''
        UserData = []
        Tooltip = ''
        FontWeight = 'normal'
        FontSize = 12
        FontColor = [0 0 0]
        FontName = 'Helvetica'
        FontAngle = 'normal'
        BackgroundColor = [0.94 0.94 0.94]
        Position = [1 1 100 22]
    end
    methods
        function obj = MockComponent(type, parent, args)
            obj.Type = type;
            if ~isempty(parent)
                if ~isa(parent, 'MockComponent')
                    error('Mock:parent', '%s needs a UI container as its parent.', type);
                end
                obj.Parent = parent;
                if isa(parent, 'MockTabGroup')
                    parent.Children{end+1} = obj;           % a tab group lists its tabs in tab order
                else
                    parent.Children = [{obj}, parent.Children];   % MATLAB lists other children newest first
                end
            end
            obj.applyArgs(args);
        end
        function applyArgs(obj, args)
            if mod(numel(args), 2) ~= 0
                error('Mock:nameValue', '%s: name-value arguments must come in pairs.', obj.Type);
            end
            for k = 1:2:numel(args)
                name = args{k};
                if ~ischar(name) || ~isprop(obj, name) || any(strcmp(name, {'Type', 'Parent', 'Children'}))
                    error('Mock:unknownProperty', '%s has no settable property ''%s''.', obj.Type, num2str(name));
                end
                obj.(name) = args{k + 1};
            end
        end
        function set.Layout(obj, value)
            if ~(isstruct(value) && isfield(value, 'Row') && isfield(value, 'Column'))
                error('Mock:layout', '%s: Layout must have Row and Column.', obj.Type);
            end
            if ~(isempty(value.Row) && isempty(value.Column)) && ~isa(obj.Parent, 'MockGridLayout')
                error('Mock:layout', '%s: Layout.Row/Column can only be set inside a uigridlayout.', obj.Type);
            end
            obj.Layout = value;
        end
        function set.Enable(obj, value)
            obj.refuseOnHTML('Enable');
            obj.Enable = value;
        end
        function set.Tooltip(obj, value)
            obj.refuseOnHTML('Tooltip');
            obj.Tooltip = value;
        end
        function set.FontSize(obj, value)
            obj.refuseOnHTML('FontSize');
            obj.FontSize = value;
        end
        function set.FontName(obj, value)
            obj.refuseOnHTML('FontName');
            obj.FontName = value;
        end
        function set.FontAngle(obj, value)
            obj.refuseOnHTML('FontAngle');
            obj.FontAngle = value;
        end
        function set.BackgroundColor(obj, value)
            obj.refuseOnHTML('BackgroundColor');
            mockCheckColor(value, [obj.Type '.BackgroundColor']);
            obj.BackgroundColor = value;
        end
        function set.FontColor(obj, value)
            obj.refuseOnHTML('FontColor');
            mockCheckColor(value, [obj.Type '.FontColor']);
            obj.FontColor = value;
        end
        function set.FontWeight(obj, value)
            obj.refuseOnHTML('FontWeight');
            if ~any(strcmp(value, {'normal', 'bold'}))
                error('Mock:value', '%s.FontWeight must be ''normal'' or ''bold''.', obj.Type);
            end
            obj.FontWeight = value;
        end
        function refuseOnHTML(obj, name)
            % MATLAB's uihtml has no visual properties: setting one (in the constructor or later) is an error there.
            if strcmp(obj.Type, 'uihtml')
                error('Mock:unknownProperty', 'uihtml has no settable property ''%s''.', name);
            end
        end
    end
end

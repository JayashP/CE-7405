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
                parent.Children{end+1} = obj;
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
        function set.BackgroundColor(obj, value)
            mockCheckColor(value, [obj.Type '.BackgroundColor']);
            obj.BackgroundColor = value;
        end
        function set.FontColor(obj, value)
            mockCheckColor(value, [obj.Type '.FontColor']);
            obj.FontColor = value;
        end
        function set.FontWeight(obj, value)
            if ~any(strcmp(value, {'normal', 'bold'}))
                error('Mock:value', '%s.FontWeight must be ''normal'' or ''bold''.', obj.Type);
            end
            obj.FontWeight = value;
        end
    end
end

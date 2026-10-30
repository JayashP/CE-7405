classdef MockDropDown < MockComponent
    %MOCKDROPDOWN Stand-in for uidropdown; Value must be one of Items.
    properties
        Items = {'Option 1', 'Option 2', 'Option 3', 'Option 4'}
        ItemsData = []
        Value = 'Option 1'
        ValueChangedFcn = []
        Editable = 'off'
        Placeholder = ''
    end
    methods
        function obj = MockDropDown(parent, args)
            obj@MockComponent('uidropdown', parent, args);
        end
        function set.Value(obj, v)
            if ~(ischar(v) && any(strcmp(v, obj.Items)))
                error('Mock:value', 'drop-down Value ''%s'' is not one of its Items.', num2str(v));
            end
            obj.Value = v;
        end
        function set.Items(obj, items)
            if ~iscellstr(items)
                error('Mock:value', 'drop-down Items must be a cell array of character vectors.');
            end
            obj.Items = items;
        end
    end
end

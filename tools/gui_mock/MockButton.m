classdef MockButton < MockComponent
    %MOCKBUTTON Stand-in for uibutton (GNU Octave app check only; generated from one property table).
    properties
        Style = 'push'
        Text = 'Button'
        ButtonPushedFcn = []
        Icon = ''
        IconAlignment = 'left'
        HorizontalAlignment = 'center'
        WordWrap = 'off'
    end
    methods
        function obj = MockButton(parent, args)
            obj@MockComponent('uibutton', parent, args);
        end
    end
end

classdef MockProgressDialog < handle
    %MOCKPROGRESSDIALOG Stand-in for uiprogressdlg.
    properties
        Title = ''
        Message = ''
        Indeterminate = 'off'
        Value = 0
        Cancelable = 'off'
        ShowPercentage = 'off'
        Icon = ''
        Interpreter = 'none'
        IsOpen = true
    end
    methods
        function obj = MockProgressDialog(fig, args)
            if ~isa(fig, 'MockFigure')
                error('Mock:parent', 'uiprogressdlg needs the app figure.');
            end
            for k = 1:2:numel(args)
                if ~isprop(obj, args{k}) || strcmp(args{k}, 'IsOpen')
                    error('Mock:unknownProperty', 'uiprogressdlg has no property ''%s''.', args{k});
                end
                obj.(args{k}) = args{k + 1};
            end
        end
    end
end

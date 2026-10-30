function obj = uibutton(parent, varargin)
%UIBUTTON Mock constructor for checking the app in GNU Octave (tools/gui_mock).
args = varargin;
if ~isempty(args) && ischar(args{1}) && any(strcmp(args{1}, {'push', 'state'}))
    args = args(2:end);
end
obj = MockButton(parent, args);
end

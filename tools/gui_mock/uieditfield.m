function obj = uieditfield(parent, varargin)
%UIEDITFIELD Mock constructor for checking the app in GNU Octave (tools/gui_mock).
style = 'text';
args = varargin;
if ~isempty(args) && ischar(args{1}) && any(strcmp(args{1}, {'text', 'numeric'}))
    style = args{1};
    args = args(2:end);
end
obj = MockEditField(parent, style, args);
end

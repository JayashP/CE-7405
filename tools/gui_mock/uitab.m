function obj = uitab(parent, varargin)
%UITAB Mock constructor for checking the app in GNU Octave (tools/gui_mock).
if ~isa(parent, 'MockTabGroup')
    error('Mock:parent', 'uitab must be created in a uitabgroup.');
end
obj = MockTab(parent, varargin);
end

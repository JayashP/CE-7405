function uialert(fig, message, titleText, varargin)
%UIALERT Mock: record the alert on the figure instead of showing it (GNU Octave app check only).
if ~isa(fig, 'MockFigure')
    error('Mock:parent', 'uialert needs the app figure.');
end
if ~(ischar(message) && ischar(titleText))
    error('Mock:value', 'uialert message and title must be character vectors.');
end
for k = 1:2:numel(varargin)
    if ~any(strcmp(varargin{k}, {'Icon', 'Modal', 'CloseFcn', 'Interpreter'}))
        error('Mock:unknownProperty', 'uialert has no option ''%s''.', varargin{k});
    end
end
fig.Alerts{end+1} = sprintf('%s: %s', titleText, message);
end

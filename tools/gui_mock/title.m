function title(ax, str)
%TITLE Mock title on a MockUIAxes (GNU Octave app check only).
if ~(isa(ax, 'MockUIAxes') && (ischar(str) || iscellstr(str)))   % a cell of lines = multi-line title, as in MATLAB
    error('Mock:value', 'title needs the app''s UIAxes and a character vector or a cell array of lines.');
end
ax.Title = str;
end

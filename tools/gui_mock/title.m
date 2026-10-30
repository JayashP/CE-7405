function title(ax, str)
%TITLE Mock title on a MockUIAxes (GNU Octave app check only).
if ~(isa(ax, 'MockUIAxes') && ischar(str))
    error('Mock:value', 'title needs the app''s UIAxes and a character vector.');
end
ax.Title = str;
end

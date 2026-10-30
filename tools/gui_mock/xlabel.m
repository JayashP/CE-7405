function xlabel(ax, str)
%XLABEL Mock xlabel on a MockUIAxes (GNU Octave app check only).
if ~(isa(ax, 'MockUIAxes') && ischar(str))
    error('Mock:value', 'xlabel needs the app''s UIAxes and a character vector.');
end
ax.XLabel = str;
end

function ylabel(ax, str)
%YLABEL Mock ylabel on a MockUIAxes (GNU Octave app check only).
if ~(isa(ax, 'MockUIAxes') && ischar(str))
    error('Mock:value', 'ylabel needs the app''s UIAxes and a character vector.');
end
ax.YLabel = str;
end

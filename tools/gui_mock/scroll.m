function scroll(target, location)
%SCROLL Mock of scroll(uitable, location) for checking the app in GNU Octave (tools/gui_mock).
%   MATLAB R2021b+ scrolls the table; the stand-in only checks the arguments.
if ~isa(target, 'MockTable')
    error('Mock:value', 'scroll: the stand-in supports tables only.');
end
if ~any(strcmp(location, {'top', 'bottom', 'left', 'right'}))
    error('Mock:value', 'scroll: unknown location.');
end
end

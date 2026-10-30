function grid(ax, varargin)
%GRID Mock of grid for a MockUIAxes (GNU Octave app check only).
if ~isa(ax, 'MockUIAxes')
    error('Mock:axes', 'grid must be called with the app''s UIAxes as first argument.');
end
switch 'grid'
    case 'cla'
        ax.Children = {};
        ax.Legend = {};
    case 'hold'
        if ~any(strcmp(varargin{1}, {'on', 'off'}))
            error('Mock:value', 'hold option must be on or off.');
        end
        ax.NextPlot = 'add';
    case 'axis'
        if ~any(strcmp(varargin{1}, {'equal', 'tight', 'normal', 'off', 'on'}))
            error('Mock:value', 'unsupported axis option.');
        end
    case 'grid'
        ax.XGrid = varargin{1};
        ax.YGrid = varargin{1};
end
end

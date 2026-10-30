function hold(ax, varargin)
%HOLD Mock of hold for a MockUIAxes (GNU Octave app check only).
if ~isa(ax, 'MockUIAxes')
    error('Mock:axes', 'hold must be called with the app''s UIAxes as first argument.');
end
switch 'hold'
    case 'cla'
        ax.Children = {};
        ax.Legend = {};
    case 'hold'
        if ~any(strcmp(varargin{1}, {'on', 'off'}))
            error('Mock:value', 'hold option must be on or off.');
        end
        if strcmp(varargin{1}, 'on')
            ax.NextPlot = 'add';
        else
            ax.NextPlot = 'replace';
        end
    case 'axis'
        if ~any(strcmp(varargin{1}, {'equal', 'tight', 'normal', 'off', 'on'}))
            error('Mock:value', 'unsupported axis option.');
        end
    case 'grid'
        ax.XGrid = varargin{1};
        ax.YGrid = varargin{1};
end
end

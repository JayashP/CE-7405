function legend(ax, labels, varargin)
%LEGEND Mock legend on a MockUIAxes: legend(ax, {labels}, 'Location', ...) (GNU Octave app check only).
if isa(ax, 'MockUIAxes') && ischar(labels) && strcmp(labels, 'off')
    ax.Legend = [];                 % legend(ax, 'off') removes the legend
    return
end
handles = [];
if isa(ax, 'MockUIAxes') && isnumeric(labels)  % legend(ax, [h1 h2 ...], {labels}, ...)
    handles = labels;
    labels = varargin{1};
    varargin = varargin(2:end);
    if ~(iscellstr(labels) && numel(labels) == numel(handles))
        error('Mock:value', 'legend: %d handles but %d labels.', numel(handles), numel(labels));
    end
    if any(handles < 1 | handles > numel(ax.Children) | handles ~= round(handles))
        error('Mock:value', 'legend: a handle is not a graphics object on these axes.');
    end
end
if ~(isa(ax, 'MockUIAxes') && iscellstr(labels))
    error('Mock:value', 'legend needs the app''s UIAxes and a cell array of labels.');
end
for k = 1:2:numel(varargin)
    if ~any(strcmp(varargin{k}, {'Location', 'Orientation', 'Box'}))
        error('Mock:unknownProperty', 'legend has no option ''%s''.', varargin{k});
    end
end
visible = 0;
for k = 1:numel(ax.Children)
    g = ax.Children{k};
    args = g.Args;
    hidden = false;
    for j = 1:numel(args) - 1
        if ischar(args{j}) && strcmp(args{j}, 'HandleVisibility') && strcmp(args{j + 1}, 'off')
            hidden = true;
        end
    end
    visible = visible + ~hidden;
end
if isempty(handles) && visible ~= numel(labels)
    error('Mock:value', 'legend has %d labels but %d visible graphics objects.', numel(labels), visible);
end
lg = struct();
lg.String = labels;                 % like MATLAB's Legend object: labels in .String
ax.Legend = lg;
end

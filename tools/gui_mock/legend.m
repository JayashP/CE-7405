function legend(ax, labels, varargin)
%LEGEND Mock legend on a MockUIAxes: legend(ax, {labels}, 'Location', ...) (GNU Octave app check only).
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
if visible ~= numel(labels)
    error('Mock:value', 'legend has %d labels but %d visible graphics objects.', numel(labels), visible);
end
ax.Legend = labels;
end

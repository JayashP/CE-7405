function obj = uigridlayout(parent, varargin)
%UIGRIDLAYOUT Mock constructor for checking the app in GNU Octave (tools/gui_mock).
args = varargin;
if ~isempty(args) && isnumeric(args{1})
    sz = args{1};
    args = args(2:end);
else
    sz = [2 2];
end
if ~(isnumeric(sz) && numel(sz) == 2 && all(sz >= 1))
    error('Mock:value', 'uigridlayout size must be [rows columns].');
end
obj = MockGridLayout(parent, args);
obj.RowHeight = repmat({'1x'}, 1, sz(1));
obj.ColumnWidth = repmat({'1x'}, 1, sz(2));
end

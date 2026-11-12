function g = mockAxesCall(type, ax, allowed, nameValue, varargin)
%MOCKAXESCALL Shared checks for the graphics shims: axes type, data sizes and property names.
if ~isa(ax, 'MockUIAxes')
    error('Mock:axes', '%s must be called with the app''s UIAxes as first argument.', type);
end
if mod(numel(nameValue), 2) ~= 0
    error('Mock:nameValue', '%s: name-value arguments must come in pairs.', type);
end
for k = 1:2:numel(nameValue)
    if ~(ischar(nameValue{k}) && any(strcmp(nameValue{k}, allowed)))
        error('Mock:unknownProperty', '%s has no property ''%s''.', type, num2str(nameValue{k}));
    end
end
ax.Children{end+1} = MockGraphic(type, [varargin, nameValue]);   % data, then the name-value options
g = numel(ax.Children);   % numeric handle (index into Children), so handles concatenate like MATLAB's [h1 h2]
end

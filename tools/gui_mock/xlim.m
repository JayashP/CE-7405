function xlim(ax, lim)
%XLIM Mock axis limits on a MockUIAxes; limits must be finite and increasing (as in MATLAB).
if ~isa(ax, 'MockUIAxes')
    error('Mock:axes', 'xlim must be called with the app''s UIAxes as first argument.');
end
if ~(isnumeric(lim) && numel(lim) == 2 && all(isfinite(lim)) && lim(1) < lim(2))
    error('Mock:value', 'xlim limits must be finite and increasing, got %s.', mat2str(lim));
end
ax.XLim = lim;
end

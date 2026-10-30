classdef MockEditField < MockComponent
    %MOCKEDITFIELD Stand-in for uieditfield ('text' or 'numeric'), with value and limit checks.
    properties
        Style = 'text'
        Value = ''
        Limits = [-Inf Inf]
        LowerLimitInclusive = 'on'
        UpperLimitInclusive = 'on'
        RoundFractionalValues = 'off'
        ValueDisplayFormat = '%11.4g'
        ValueChangedFcn = []
        ValueChangingFcn = []
        HorizontalAlignment = 'left'
        Editable = 'on'
        Placeholder = ''
    end
    methods
        function obj = MockEditField(parent, style, args)
            obj@MockComponent(['uieditfield(' style ')'], parent, {});
            obj.Style = style;
            if strcmp(style, 'numeric')
                obj.Value = 0;
            end
            obj.applyArgs(args);
        end
        function set.Value(obj, v)
            if strcmp(obj.Style, 'numeric')
                if ~(isnumeric(v) && isscalar(v) && isreal(v) && ~isnan(v))
                    error('Mock:value', 'numeric edit field Value must be a real scalar.');
                end
                lim = obj.Limits;
                lowOk = v > lim(1) || (strcmp(obj.LowerLimitInclusive, 'on') && v == lim(1));
                highOk = v < lim(2) || (strcmp(obj.UpperLimitInclusive, 'on') && v == lim(2));
                if ~(lowOk && highOk)
                    error('Mock:value', 'numeric edit field Value %g is outside Limits [%g %g].', v, lim(1), lim(2));
                end
            elseif ~(ischar(v) && (isrow(v) || isempty(v)))
                error('Mock:value', 'text edit field Value must be a character vector.');
            end
            obj.Value = v;
        end
        function set.Limits(obj, lim)
            if ~(isnumeric(lim) && numel(lim) == 2 && lim(1) <= lim(2))
                error('Mock:value', 'edit field Limits must be [low high] with low <= high.');
            end
            obj.Limits = lim;
        end
    end
end

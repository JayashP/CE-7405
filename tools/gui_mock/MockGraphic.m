classdef MockGraphic < handle
    %MOCKGRAPHIC Handle returned by the plot/patch/text shims (records the call).
    properties
        Type = ''
        Args = {}
    end
    methods
        function obj = MockGraphic(type, args)
            obj.Type = type;
            obj.Args = args;
        end
    end
end

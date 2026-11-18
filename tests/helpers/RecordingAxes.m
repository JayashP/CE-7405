classdef RecordingAxes < handle
    %RECORDINGAXES Stand-in axes that record what a plot function draws (tests only, no window).
    %   AX = RECORDINGAXES() is passed in place of real axes to plot
    %   functions such as PLOTSENSITIVITY, PLOTFITPROFILE and PLOTREADINGS.
    %   Their calls cla(AX), plot(AX, ...), patch(AX, ...), xlabel(AX, ...),
    %   legend(AX, ...), ... dispatch to the methods of this class (MATLAB and
    %   GNU Octave), which store what would be drawn instead of rendering it.
    %   A test can then compare the drawn numbers and texts without a display
    %   or a graphics toolkit. Properties:
    %     Objects        struct array, one element per plot or patch call:
    %                    kind ('line' or 'patch'), x, y (as passed) and
    %                    options (name-value cell; a patch colour is stored
    %                    as 'FaceColor')
    %     XLabel, YLabel, Title, XLim, YLim
    %     Legend         cell of legend labels; LegendHandles the handles
    %                    passed with them (indices into Objects)
    %   CLA empties Objects, like CLA on real axes; HOLD and GRID are
    %   accepted and ignored. S = RECORDED(AX) returns all of it as one
    %   struct, so two drawings can be compared with ISEQUAL.
    %   It checks only what the plot function passes, not how MATLAB or
    %   Octave would render it.
    %
    %   See also PLOTSENSITIVITY, PLOTFITPROFILE, PLOTREADINGS.

    properties
        Objects = struct('kind', {}, 'x', {}, 'y', {}, 'options', {})
        XLabel = ''
        YLabel = ''
        Title = ''
        XLim = []
        YLim = []
        Legend = {}
        LegendHandles = []
    end

    methods
        function h = plot(ax, x, y, varargin)
            h = addObject(ax, 'line', x, y, varargin);
        end

        function h = patch(ax, x, y, color, varargin)
            h = addObject(ax, 'patch', x, y, [{'FaceColor', color}, varargin]);
        end

        function cla(ax)
            ax.Objects = struct('kind', {}, 'x', {}, 'y', {}, 'options', {});
        end

        function hold(ax, state) %#ok<INUSD>
        end

        function grid(ax, state) %#ok<INUSD>
        end

        function xlabel(ax, text)
            ax.XLabel = text;
        end

        function ylabel(ax, text)
            ax.YLabel = text;
        end

        function title(ax, text)
            ax.Title = text;
        end

        function xlim(ax, limits)
            ax.XLim = limits;
        end

        function ylim(ax, limits)
            ax.YLim = limits;
        end

        function legend(ax, handles, labels, varargin)
            ax.LegendHandles = handles;
            ax.Legend = labels;
        end

        function s = recorded(ax)
            s = struct('Objects', ax.Objects, 'XLabel', ax.XLabel, 'YLabel', ax.YLabel, 'Title', {ax.Title}, ...
                'XLim', ax.XLim, 'YLim', ax.YLim, 'Legend', {ax.Legend}, 'LegendHandles', ax.LegendHandles);
        end

        function h = addObject(ax, kind, x, y, options)
            ax.Objects(end+1) = struct('kind', kind, 'x', x, 'y', y, 'options', {options});
            h = numel(ax.Objects);
        end
    end
end

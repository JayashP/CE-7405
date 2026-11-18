classdef RecordingAxes < handle
    %RECORDINGAXES Stand-in axes that record what a plot function draws (tests only, no window).
    %   AX = RECORDINGAXES() is passed in place of real axes to plot
    %   functions such as PLOTSENSITIVITY, PLOTFITPROFILE and PLOTREADINGS.
    %   Their calls cla(AX), plot(AX, ...), patch(AX, ...), xlabel(AX, ...),
    %   legend(AX, ...), ... dispatch to the methods of this class (MATLAB and
    %   GNU Octave), which store what would be drawn instead of rendering it.
    %   GNU Octave cannot create real axes without a display, so this lets
    %   the test suite compare the drawn numbers and texts on any machine.
    %   S = RECORDED(AX) returns the record as a struct (two drawings can be
    %   compared with ISEQUAL):
    %     Objects        struct array, one element per PLOT or PATCH call:
    %                    kind ('line' or 'patch'), x, y (as passed) and
    %                    options (name-value cell; a patch colour is stored
    %                    as 'FaceColor')
    %     XLabel, YLabel, Title, XLim, YLim   as passed
    %     Legend         cell of legend labels; LegendHandles the handles
    %                    passed with them (indices into Objects)
    %   CLA empties Objects, like CLA on real axes; HOLD and GRID are
    %   accepted and ignored. It checks only what the plot function passes,
    %   not how MATLAB or Octave would render it.
    %
    %   See also PLOTSENSITIVITY, PLOTFITPROFILE, PLOTREADINGS.

    properties
        Record = struct('Objects', {struct('kind', {}, 'x', {}, 'y', {}, 'options', {})}, 'XLabel', '', ...
            'YLabel', '', 'Title', '', 'XLim', [], 'YLim', [], 'Legend', {{}}, 'LegendHandles', [])
    end

    methods
        function s = recorded(ax)
            s = ax.Record;
        end

        function h = plot(ax, x, y, varargin)
            h = addObject(ax, 'line', x, y, varargin);
        end

        function h = patch(ax, x, y, color, varargin)
            h = addObject(ax, 'patch', x, y, [{'FaceColor', color}, varargin]);
        end

        function cla(ax)
            r = ax.Record;
            r.Objects = r.Objects([]);
            ax.Record = r;
        end

        function hold(ax, state) %#ok<INUSD>
        end

        function grid(ax, state) %#ok<INUSD>
        end

        function xlabel(ax, label)
            setField(ax, 'XLabel', label);
        end

        function ylabel(ax, label)
            setField(ax, 'YLabel', label);
        end

        function title(ax, label)
            setField(ax, 'Title', label);
        end

        function xlim(ax, limits)
            setField(ax, 'XLim', limits);
        end

        function ylim(ax, limits)
            setField(ax, 'YLim', limits);
        end

        function legend(ax, handles, labels, varargin)
            setField(ax, 'LegendHandles', handles);
            setField(ax, 'Legend', labels);
        end

        function setField(ax, name, value)
            r = ax.Record;
            r.(name) = value;
            ax.Record = r;
        end

        function h = addObject(ax, kind, x, y, options)
            r = ax.Record;
            r.Objects(end+1) = struct('kind', kind, 'x', x, 'y', y, 'options', {options});
            ax.Record = r;
            h = numel(r.Objects);
        end
    end
end

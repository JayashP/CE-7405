function html = infoPanelHtml(kind, lines, flags)
%INFOPANELHTML One of the app's information boxes as formatted HTML (HTMLPANEL).
%   HTML = INFOPANELHTML(KIND, LINES) groups the text LINES written by the
%   engine helpers under headings and returns HTMLPANEL output. The words
%   are not changed; only headings, bullets and colours are added.
%   HTML = INFOPANELHTML(KIND, LINES, FLAGS) also marks the lines that are
%   limiting flags (IDENTIFICATIONSUMMARY's second output) in orange.
%   KIND:
%     'model'        model summary (BUILDMODELFROMTABLES info.summary):
%                    Model, Supports (one bullet each), Material and load,
%                    and the modelling notes in grey; two columns
%     'envelope'     moving-load run notes (vehicle, positions; last line grey)
%     'damage'       applied damage (first line) and its caveat (grey)
%     'findings'     DAMAGECOMPARISONSUMMARY lines (first line as the lead)
%     'identBox'     the flags first (orange, so a small box always shows
%                    them), then the best fit, then the pointer to the
%                    Summary tab (grey)
%     'identSummary' IDENTIFICATIONSUMMARY lines: the method, Result,
%                    Checks and flags (orange; a passed fit check green;
%                    a flag that is not one of the lines, such as the ratio
%                    method's warning, is listed here too), Test case,
%                    Notes (grey)
%     'message'      instructions or a hint, one paragraph per line
%
%   See also HTMLPANEL, BRIDGECONDITIONAPP.

if nargin < 3
    flags = {};
end
columns = 1;
lines = cellstr(lines);
lines = lines(:)';
flags = cellstr(flags);
switch kind
    case 'model'
        s = section('Model', {}, 'list');
        sup = section('Supports', {}, 'list');
        mat = section('Material and load', {}, 'list');
        for k = 1:numel(lines)
            t = lines{k};
            if strncmp(t, 'Supports: ', 10)
                sup.items = regexp(t(11:end), '(?<=\)), ', 'split');   % 'A Pin (x = 0 m), B Roller (...)'
            elseif strncmp(t, 'Material:', 9) || strncmp(t, 'Basis:', 6)
                mat.items{end+1} = t;
            elseif strncmp(t, 'Permanent uniform load:', 23)
                mat.items{end+1} = t;
            elseif ~isempty(t)
                s.items{end+1} = t;
            end
        end
        notes = section('Modelling notes', {'Model: 2D equivalent Euler-Bernoulli beam, DOFs v and theta per node.', ...
            ['Supports: pin and roller act alike in this bending-only model (no horizontal direction); Free = no ' ...
            'support, e.g. a cantilever tip.'], ...
            'Steel: EI = Es*Is. RCC: EI = Ec*Ieff, with Ieff supplied by you and held constant (no cracking model).', ...
            'Linear, quasi-static analysis. Not a load rating or design check.'}, 'note');
        parts = [s, sup, mat, notes];
        columns = 2;                                 % the summary box is wide and short
    case 'envelope'
        parts = [section('Moving-load run', lines(1:end-1), 'list'), section('', lines(end), 'note')];
    case 'damage'
        parts = [section('Applied damage', lines(1), 'list'), section('', lines(2:end), 'note')];
    case 'findings'
        parts = [section('Findings', lines(1), 'lead'), section('', lines(2:end), 'list')];
    case 'identBox'
        items = lines;
        last = numel(items);
        if last >= 1 && strncmp(items{last}, 'Full result', 11)
            note = items(last);
            items = items(1:last - 1);
        else
            note = {};
        end
        lead = items(1);
        warnings = cellfun(@(t) {'warn', t}, items(2:end), 'UniformOutput', false);
        parts = [section('', warnings, 'list'), section('', lead, 'lead'), section('', note, 'note')];
    case 'identSummary'
        method = {};
        result = {};
        checks = {};
        test = {};
        notes = {};
        for k = 1:numel(lines)
            t = lines{k};
            if strncmp(t, 'Method:', 7)
                method{end+1} = t; %#ok<AGROW>
            elseif any(strcmp(t, flags)) || strncmp(t, 'FIT CHECK FAILED', 16) || strncmp(t, 'Damage cannot be ruled out', 26)
                checks{end+1} = {'warn', t}; %#ok<AGROW>
            elseif strncmp(t, 'Fit check passed', 16)
                checks{end+1} = {'ok', t}; %#ok<AGROW>
            elseif strncmp(t, 'Synthetic test case', 19) || strncmp(t, 'The candidate regions are longer', 32)
                test{end+1} = t; %#ok<AGROW>
            elseif strncmp(t, 'Self-generated', 14) || strncmp(t, 'The result locates', 18)
                notes{end+1} = t; %#ok<AGROW>
            else
                result{end+1} = t; %#ok<AGROW>
            end
        end
        % A flag that is not one of the lines (the ratio method's warning; the short FIT CHECK FAILED form
        % stands for the long line) is listed with the checks, in the engine's words.
        for k = 1:numel(flags)
            if ~any(strcmp(flags{k}, lines)) && ~strncmp(flags{k}, 'FIT CHECK FAILED', 16)
                checks = [{{'warn', flags{k}}}, checks]; %#ok<AGROW>
            end
        end
        parts = [section('', method, 'lead'), section('Result', result, 'list'), ...
            section('Checks and flags', checks, 'list'), section('Test case', test, 'list'), ...
            section('Notes', notes, 'note')];
    case 'message'
        parts = section('', lines, 'lead');
    otherwise
        error('BridgeFE:invalidInput', 'Unknown information box ''%s''.', kind);
end
parts = parts(~cellfun(@isempty, {parts.items}));      % no empty headings
html = htmlPanel(parts, columns);
end

function s = section(title, items, kind)
s = struct('title', title, 'items', {items}, 'kind', kind);
end

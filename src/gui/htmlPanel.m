function html = htmlPanel(sections)
%HTMLPANEL Formatted HTML for the app's information boxes (headings, bullets, highlighted numbers).
%   HTML = HTMLPANEL(SECTIONS) returns one HTML document for a MATLAB
%   UIHTML component. SECTIONS is a struct array with fields
%     title   heading text ('' for none)
%     items   cellstr, one bullet (or paragraph) per entry
%     kind    'list'  bullets (default)
%             'lead'  paragraphs without bullets
%             'note'  small grey bullets (standing notes and caveats)
%   An item may start with a tag that colours it:
%     '[warn] '  orange with a warning sign (limiting flags, failed checks)
%     '[ok] '    green with a tick (checks that passed)
%   Text is escaped (&, <, >). A short label before the first ': ' that
%   holds no '=' is set in bold ('Spans: 20 m' -> <b>Spans</b>: 20 m).
%   Numbers, with their unit when one follows ('20 m', '-24.925 mm',
%   '2e+06 kN*m^2', '27.0-33.0 %'), are bold and blue; numbers that are
%   part of a name ('S1', 'HL-93', '2D', '3-axle') are left alone.
%   The wording is never changed, so a box shows the same text as the
%   engine helper that wrote it.
%
%   Example:
%     html = htmlPanel(struct('title', 'Model', 'items', {{'Spans: 20 m (total 20 m)'}}, 'kind', 'list'));
%
%   See also INFOPANELHTML, BRIDGECONDITIONAPP.

style = ['<style>' ...
    'body{font-family:Helvetica,Arial,sans-serif;font-size:12px;color:#262626;margin:4px 8px;line-height:1.35;}' ...
    'h4{font-size:12px;color:#0b4f8a;margin:6px 0 2px 0;border-bottom:1px solid #d6e4f0;}' ...
    'ul{margin:1px 0 3px 0;padding-left:16px;}li{margin:1px 0;}p{margin:2px 0 3px 0;}' ...
    '.num{color:#0072BD;font-weight:bold;}' ...
    '.warn{color:#b5400f;}.warn .num{color:#b5400f;}' ...
    '.ok{color:#2e7d32;}.ok .num{color:#2e7d32;}' ...
    '.note{color:#6b6b6b;font-size:11px;}.note .num{color:#6b6b6b;font-weight:normal;}' ...
    '</style>'];
body = '';
for s = 1:numel(sections)
    sec = sections(s);
    kind = 'list';
    if isfield(sec, 'kind') && ~isempty(sec.kind)
        kind = sec.kind;
    end
    if ~isempty(sec.title)
        body = [body, '<h4>', escapeHtml(sec.title), '</h4>']; %#ok<AGROW>
    end
    items = sec.items;
    if ischar(items)
        items = {items};
    end
    parts = cell(1, numel(items));
    for k = 1:numel(items)
        [text, cls] = splitTag(items{k});
        if strcmp(kind, 'note')
            cls = strtrim([cls, ' note']);
        end
        inner = formatItem(text);
        if strcmp(cls, 'warn') || strcmp(cls, 'warn note')
            inner = ['&#9888; ', inner];
        elseif strcmp(cls, 'ok') || strcmp(cls, 'ok note')
            inner = ['&#10004; ', inner];
        end
        attr = '';
        if ~isempty(cls)
            attr = sprintf(' class="%s"', cls);
        end
        if strcmp(kind, 'lead')
            parts{k} = sprintf('<p%s>%s</p>', attr, inner);
        else
            parts{k} = sprintf('<li%s>%s</li>', attr, inner);
        end
    end
    if strcmp(kind, 'lead')
        body = [body, strjoin(parts, '')]; %#ok<AGROW>
    elseif ~isempty(parts)
        body = [body, '<ul>', strjoin(parts, ''), '</ul>']; %#ok<AGROW>
    end
end
html = ['<!DOCTYPE html><html><head><meta charset="utf-8">', style, '</head><body>', body, '</body></html>'];
end

function [text, cls] = splitTag(item)
% '[warn] text' -> ('text', 'warn'); '[ok] text' -> ('text', 'ok'); otherwise no class.
cls = '';
text = item;
tags = {'[warn] ', 'warn'; '[ok] ', 'ok'};
for k = 1:size(tags, 1)
    if strncmp(item, tags{k, 1}, numel(tags{k, 1}))
        cls = tags{k, 2};
        text = item(numel(tags{k, 1}) + 1:end);
    end
end
end

function out = formatItem(text)
% Escape, bold a short leading label, highlight numbers with their units.
label = '';
rest = text;
colon = strfind(text, ': ');
if ~isempty(colon) && colon(1) <= 48 && isempty(strfind(text(1:colon(1)), '='))
    label = text(1:colon(1) - 1);
    rest = text(colon(1):end);
end
out = highlightNumbers(escapeHtml(rest));
if ~isempty(label)
    out = ['<b>', escapeHtml(label), '</b>', out];
end
end

function out = highlightNumbers(text)
% Wrap stand-alone numbers (signed, decimal, exponent, ranges 'a-b') and a following unit in a span.
units = '(?:\s?(?:%|kN\*m\^2|kip\*ft\^2|kN\*m|kip\*ft|kN/m|kip/ft|kN|kip|GPa|ksi|m\^4|in\^4|mm|m|ft|in))?';
number = '-?\d+(?:\.\d+)?(?:e[+-]?\d+)?(?:-\d+(?:\.\d+)?)?';
% The character before the number is captured (not a look-behind, which Octave's engine rejects here);
% a leading space gives a number at the very start a character to capture (Octave drops empty tokens).
pattern = ['([^\w.\-^*/])(', number, units, ')(?![\w^*/]|\.\d|-[A-Za-z])'];   % '1.' ends a sentence
out = regexprep([' ', text], pattern, '$1<span class="num">$2</span>');
out = out(2:end);
end

function out = escapeHtml(text)
out = strrep(text, '&', '&amp;');
out = strrep(out, '<', '&lt;');
out = strrep(out, '>', '&gt;');
end

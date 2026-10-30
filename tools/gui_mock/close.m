function close(varargin)
%CLOSE Mock: closes a MockProgressDialog; ignores 'close all' (no figures exist in the GNU Octave app check).
if numel(varargin) == 1 && isa(varargin{1}, 'MockProgressDialog')
    varargin{1}.IsOpen = false;
elseif ~(numel(varargin) >= 1 && ischar(varargin{1}) && strcmp(varargin{1}, 'all'))
    builtin('close', varargin{:});
end
end

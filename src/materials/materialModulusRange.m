function range = materialModulusRange(type)
%MATERIALMODULUSRANGE Usual elastic modulus range [Pa] for the unit-sanity warning.
%   RANGE = MATERIALMODULUSRANGE(TYPE) returns [lower, upper] in Pa:
%   'steel' 150-250 GPa, 'rcc' 10-70 GPa. These are broad plausibility
%   bounds that catch unit slips (e.g. 200 typed instead of 200e9 Pa), not
%   engineering limits. Used by DEFINEMATERIAL (engine warning, in Pa) and
%   BUILDMODELFROMTABLES (the app's message, in the display unit).
%
%   See also DEFINEMATERIAL, BUILDMODELFROMTABLES.

if strcmpi(type, 'steel')
    range = [150e9, 250e9];
elseif strcmpi(type, 'rcc')
    range = [10e9, 70e9];
else
    error('BridgeFE:invalidMaterial', 'Material type must be ''steel'' or ''rcc''.');
end
end

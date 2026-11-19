function opts = identificationOptions(model, regionLength, noisePercent, noiseAbsolute, direction, U)
%IDENTIFICATIONOPTIONS Name-value options for IDENTIFYSINGLEDAMAGE from the Stage 3 tab inputs.
%   OPTS = IDENTIFICATIONOPTIONS(MODEL, REGIONLENGTH, NOISEPERCENT,
%   NOISEABSOLUTE, DIRECTION) returns {'Direction', DIRECTION, ...} plus
%     'Groups'        CANDIDATEGROUPS(MODEL, REGIONLENGTH) when REGIONLENGTH > 0
%     'NoiseLevel'    NOISEPERCENT / 100 when NOISEPERCENT > 0
%     'NoiseAbsolute' NOISEABSOLUTE [mm] / 1000 [m] when NOISEABSOLUTE > 0
%   With both noise inputs 0 the search uses the 'ratio' method (no
%   confidence region); otherwise the noise-based 'likelihood' method.
%   OPTS = IDENTIFICATIONOPTIONS(..., DIRECTION, U) reads NOISEABSOLUTE in
%   U.deflection (display units U of UNITSYSTEM, e.g. in for 'US').
%   REGIONLENGTH is always in m (from CANDIDATEREGIONLENGTH).
%
%   See also IDENTIFYSINGLEDAMAGE, CANDIDATEGROUPS, CANDIDATEREGIONLENGTH, UNITSYSTEM.

if nargin < 6 || isempty(U)
    U = unitSystem('SI');
end
names = {'Region length [m]', 'Noise [%]', sprintf('Absolute noise [%s]', U.deflection.unit)};
values = {regionLength, noisePercent, noiseAbsolute};
for k = 1:3
    assertFiniteRealScalar(values{k}, names{k});
    if values{k} < 0
        error('BridgeFE:invalidInput', '%s must be 0 or more.', names{k});
    end
end
opts = {'Direction', direction};
if regionLength > 0
    opts = [opts, {'Groups', candidateGroups(model, regionLength)}];
end
if noisePercent > 0
    opts = [opts, {'NoiseLevel', noisePercent / 100}];
end
perM = 1 / U.deflection.toSI;                % deflection display units per m (1000 for mm, exactly)
if noiseAbsolute > 0
    opts = [opts, {'NoiseAbsolute', noiseAbsolute / perM}];
end
end

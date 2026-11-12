function opts = identificationOptions(model, regionLength, noisePercent, noiseAbsoluteMm, direction)
%IDENTIFICATIONOPTIONS Name-value options for IDENTIFYSINGLEDAMAGE from the Stage 3 tab inputs.
%   OPTS = IDENTIFICATIONOPTIONS(MODEL, REGIONLENGTH, NOISEPERCENT,
%   NOISEABSOLUTEMM, DIRECTION) returns {'Direction', DIRECTION, ...} plus
%     'Groups'        CANDIDATEGROUPS(MODEL, REGIONLENGTH) when REGIONLENGTH > 0
%     'NoiseLevel'    NOISEPERCENT / 100 when NOISEPERCENT > 0
%     'NoiseAbsolute' NOISEABSOLUTEMM / 1000 [m] when NOISEABSOLUTEMM > 0
%   With both noise inputs 0 the search uses the 'ratio' method (no
%   confidence region); otherwise the noise-based 'likelihood' method.
%
%   See also IDENTIFYSINGLEDAMAGE, CANDIDATEGROUPS.

names = {'Region length [m]', 'Noise [%]', 'Absolute noise [mm]'};
values = {regionLength, noisePercent, noiseAbsoluteMm};
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
if noiseAbsoluteMm > 0
    opts = [opts, {'NoiseAbsolute', noiseAbsoluteMm / 1000}];
end
end

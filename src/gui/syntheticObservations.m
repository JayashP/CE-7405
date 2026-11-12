function [uObs, truth] = syntheticObservations(model, vehicle, positions, sensorX, direction, xFrom, xTo, dPercent, noisePercent, seed)
%SYNTHETICOBSERVATIONS Synthetic sensor readings of a hidden damage case for the Stage 3 tab.
%   [UOBS, TRUTH] = SYNTHETICOBSERVATIONS(MODEL, VEHICLE, POSITIONS, SENSORX,
%   DIRECTION, XFROM, XTO, DPERCENT, NOISEPERCENT, SEED) applies a loss of
%   DPERCENT % to the elements between the node coordinates XFROM and XTO
%   [m] of the healthy MODEL, predicts the vehicle-only deflections at
%   SENSORX for the front-axle POSITIONS (PREDICTSENSORDEFLECTIONS) and adds
%   proportional noise of NOISEPERCENT % with the reproducible SEED
%   (ADDMEASUREMENTNOISE). DPERCENT = 0 gives an undamaged case (XFROM and
%   XTO are then not used).
%   UOBS [m] (sensors x positions) is what the search receives. TRUTH
%   (elements, x, d, noise, seed) is kept apart, so the search is blind to
%   it; it is shown only afterwards for comparison. Agreement with such
%   self-generated data is algorithm verification, not field validation.
%
%   See also IDENTIFYSINGLEDAMAGE, PREDICTSENSORDEFLECTIONS, ADDMEASUREMENTNOISE.

for v = {dPercent, noisePercent, seed}
    assertFiniteRealScalar(v{1}, 'Synthetic case input');
end
if dPercent < 0 || dPercent >= 100
    error('BridgeFE:invalidInput', 'Hidden loss must be at least 0 %% and below 100 %%.');
end
if noisePercent < 0
    error('BridgeFE:invalidInput', 'Noise must be 0 %% or more.');
end
if seed < 0 || seed ~= round(seed)
    error('BridgeFE:invalidInput', 'Seed must be a whole number of 0 or more.');
end
damaged = model;
elements = [];
xTrue = [NaN NaN];
if dPercent > 0
    elements = elementsBetween(model, xFrom, xTo);
    damaged = applyStiffnessDamage(model, elements, dPercent / 100);
    xTrue = [xFrom, xTo];
end
u = predictSensorDeflections(damaged, vehicle, positions, sensorX, direction);
uObs = addMeasurementNoise(u, noisePercent / 100, seed);
truth = struct('elements', elements(:)', 'x', xTrue, 'd', dPercent / 100, 'noise', noisePercent / 100, 'seed', seed);
end

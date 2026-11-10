function [uNoisy, sigma] = addMeasurementNoise(u, level, seed, model)
%ADDMEASUREMENTNOISE Synthetic Gaussian measurement noise for Stage 3 test cases.
%   [UNOISY, SIGMA] = ADDMEASUREMENTNOISE(U, LEVEL, SEED) adds independent
%   Gaussian noise proportional to each reading (the usual definition of
%   "LEVEL x 100 % noise" in damage-identification studies):
%       u_noisy(i) = u(i) * (1 + LEVEL * z(i)),  z(i) ~ N(0, 1)
%   SIGMA (same size as U) holds the standard deviation LEVEL*|u(i)|.
%   ADDMEASUREMENTNOISE(U, LEVEL, SEED, 'rms') instead adds noise of one
%   constant standard deviation SIGMA = LEVEL * RMS(U) to every reading (a
%   sensor with a fixed absolute resolution; small readings are then
%   relatively noisier).
%   Missing (NaN) entries stay NaN. z comes from
%   DETERMINISTICNORMAL(numel(U), SEED), so a case is identical in MATLAB
%   and GNU Octave. This creates SYNTHETIC data for algorithm verification
%   only; it is not a model of a particular real sensor (DECISIONS.md D-028).
%
%   See also DETERMINISTICNORMAL, IDENTIFYSINGLEDAMAGE.

if nargin < 4
    model = 'proportional';
end
if ~(isnumeric(level) && isscalar(level) && isfinite(level) && level >= 0)
    error('BridgeFE:invalidInput', 'Noise level must be a finite number >= 0 (e.g. 0.02 for 2 %%).');
end
known = ~isnan(u);
z = reshape(deterministicNormal(numel(u), seed), size(u));
switch model
    case 'proportional'
        sigma = level * abs(u);
        uNoisy = u .* (1 + level * z);
    case 'rms'
        sigma = level * sqrt(mean(u(known).^2)) * ones(size(u));
        uNoisy = u + sigma .* z;
    otherwise
        error('BridgeFE:invalidInput', 'Noise model must be ''proportional'' or ''rms''.');
end
uNoisy(~known) = NaN;
sigma(~known) = NaN;
end

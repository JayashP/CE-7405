function t = appTheme()
%APPTHEME Sage-green colour theme of the bridge app and its drawings.
%   T = APPTHEME() returns RGB triplets in [0, 1]: a light sage page and
%   panels, sage accents, and muted, distinguishable colours for the beam,
%   supports, permanent loads, vehicle axles, deformed shape and the M, V
%   and v diagrams (PROJECT_SPEC.md section 9). Legibility comes first.
%
%   See also BRIDGECONDITIONAPP, BRIDGEDRAWING.

t.background = [0.929 0.945 0.922];   % page
t.panel      = [0.973 0.980 0.969];   % input panels and status bar
t.sage       = [0.612 0.686 0.533];   % accents and buttons (#9CAF88)
t.sageDark   = [0.329 0.420 0.333];   % headings
t.text       = [0.169 0.224 0.173];
t.buttonText = [1.000 1.000 1.000];
t.beam       = [0.176 0.216 0.180];
t.support    = [0.247 0.290 0.251];
t.load       = [0.647 0.247 0.200];   % permanent loads
t.vehicle    = [0.169 0.357 0.529];   % axles on the bridge and truck body
t.vehicleOff = [0.650 0.690 0.720];   % axles not on the bridge
t.deformed   = [0.820 0.451 0.118];
t.moment     = [0.329 0.420 0.333];
t.shear      = [0.545 0.427 0.200];
t.deflection = [0.204 0.392 0.580];
t.envelopeMax = [0.647 0.247 0.200];
t.envelopeMin = [0.169 0.357 0.529];
t.damage     = [0.580 0.235 0.557];   % elements with a prescribed stiffness loss (Stage 2)
end

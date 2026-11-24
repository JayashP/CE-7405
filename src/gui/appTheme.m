function t = appTheme()
%APPTHEME MATLAB-style colour theme of the bridge app and its drawings.
%   T = APPTHEME() returns RGB triplets in [0, 1] (DECISIONS.md D-031): a
%   light grey window with white panels, MATLAB blue (#0072BD) action
%   buttons and accents, dark text, and plot and drawing colours from
%   MATLAB's default line colours. Thin lines use only the colours that
%   pass contrast and colour-blind separation on white (blue, orange,
%   purple, dark red); MATLAB's yellow is used only as a light fill.
%   Every colour used in the beam drawings is distinct, so drawing items
%   can be told apart (and tested) by colour. Slides keep the sage theme
%   (not part of the app). Field names are kept from the earlier sage
%   theme: 'sage' is the accent (button) colour and 'sageDark' the
%   heading colour.
%
%   See also BRIDGECONDITIONAPP, BRIDGEDRAWING.

blue      = [0.000 0.447 0.741];   % MATLAB #0072BD
orange    = [0.851 0.325 0.098];   % MATLAB #D95319
purple    = [0.494 0.184 0.557];   % MATLAB #7E2F8E
darkRed   = [0.635 0.078 0.184];   % MATLAB #A2142F

t.background = [0.941 0.941 0.941];   % window (#F0F0F0)
t.panel      = [1.000 1.000 1.000];   % input panels and status bar
t.sage       = blue;                  % accent: action buttons
t.sageDark   = [0.149 0.149 0.149];   % headings and panel titles
t.text       = [0.149 0.149 0.149];
t.buttonText = [1.000 1.000 1.000];
t.beam       = [0.200 0.200 0.200];
t.support    = [0.330 0.330 0.330];
t.load       = darkRed;               % permanent loads
t.vehicle    = blue;                  % axles on the bridge and truck body
t.vehicleOff = [0.650 0.650 0.650];   % axles not on the bridge
t.deformed   = orange;
t.moment     = blue;
t.shear      = purple;
t.deflection = orange;
t.envelopeMax = blue;
t.envelopeMin = orange;
t.damage     = purple;                % elements with a prescribed stiffness loss (Stage 2)
% Healthy vs damaged envelopes (Stage 2): one colour per curve, all solid; healthy in blues, damaged in
% dark red / orange. The lighter healthy blue still reads on white (contrast about 3.3:1 for a thin line).
t.healthyMax = blue;
t.healthyMin = [0.200 0.580 0.860];   % lighter blue
t.damagedMax = darkRed;
t.damagedMin = orange;
t.sensor     = [0.000 0.500 0.500];   % deflection sensors (Stage 3), dark teal
t.region     = [0.980 0.902 0.706];   % region of uncertainty (Stage 3), light MATLAB yellow fill
t.regionBest = [0.749 0.392 0.000];   % best-fit region (Stage 3), dark amber
t.truth      = [0.100 0.100 0.100];   % hidden true region of a synthetic test case
t.candidate  = [0.780 0.780 0.780];   % candidate regions outside the region of uncertainty
end

function [damaged, elements, info] = damageModelFromInputs(model, xFrom, xTo, dPercent)
%DAMAGEMODELFROMINPUTS Damaged model from the app's Damage tab (region in m, loss in %).
%   [DAMAGED, ELEMENTS, INFO] = DAMAGEMODELFROMINPUTS(MODEL, XFROM, XTO, DPERCENT)
%   applies the effective-stiffness loss d = DPERCENT/100 (0 <= d < 1) to
%   the elements between the node coordinates XFROM < XTO [m]
%   (ELEMENTSBETWEEN; an off-node coordinate throws 'BridgeFE:notOnNode'),
%   using APPLYSTIFFNESSDAMAGE on MODEL (the healthy model). INFO.summary is
%   a one-line description. EI_D = (1 - d) EI is a loss of MODEL flexural
%   rigidity, not a measure of real damage (PROJECT_SPEC.md section 6).
%
%   See also APPLYSTIFFNESSDAMAGE, ELEMENTSBETWEEN, BRIDGECONDITIONAPP.

assertFiniteRealScalar(xFrom, 'Damaged region from [m]');
assertFiniteRealScalar(xTo, 'Damaged region to [m]');
assertFiniteRealScalar(dPercent, 'Stiffness loss [%]');
if dPercent < 0 || dPercent >= 100
    error('BridgeFE:invalidInput', 'Stiffness loss must be at least 0 %% and below 100 %%.');
end
elements = elementsBetween(model, xFrom, xTo);
damaged = applyStiffnessDamage(model, elements, dPercent / 100);
info.summary = sprintf('Elements %d-%d (x = %g to %g m): EI_D = (1 - %.4g) EI = %.4g EI', ...
    elements(1), elements(end), xFrom, xTo, dPercent / 100, 1 - dPercent / 100);
end

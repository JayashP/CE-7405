function [labels, engineTypes] = supportTypeList()
%SUPPORTTYPELIST Support types offered in the app's support table and their engine names.
%   [LABELS, ENGINETYPES] = SUPPORTTYPELIST() returns the drop-down labels
%   of the support table and, in the same order, the support types used
%   by the engine (ADDSUPPORT, SUPPORTSYMBOLGEOMETRY):
%     LABELS       {'Pin', 'Roller', 'Fixed', 'Free'}
%     ENGINETYPES  {'pin', 'roller', 'fixed', 'none'}
%   'Free' means no support at that span end. Guided supports are not
%   offered (DECISIONS.md D-031).
%
%   See also BUILDMODELFROMTABLES, SUPPORTLETTERS, ADDSUPPORT.

labels = {'Pin', 'Roller', 'Fixed', 'Free'};
engineTypes = {'pin', 'roller', 'fixed', 'none'};
end

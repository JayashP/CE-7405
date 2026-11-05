function EIeff = effectiveEI(model)
%EFFECTIVEEI Flexural rigidity used in the analysis: material EI times the stiffness factor.
%   EIEFF = EFFECTIVEEI(MODEL) returns the NE-by-1 vector
%       EIeff = model.elements.EI .* model.elements.stiffnessFactor   [N*m^2]
%   where stiffnessFactor = 1 - d holds the prescribed effective-stiffness
%   loss d of each element (APPLYSTIFFNESSDAMAGE; 1 = healthy). Every engine
%   function that computes with EI uses this value, so the material record
%   (model.elements.EI = E*I) is never overwritten by damage
%   (DECISIONS.md D-022, D-025).
%
%   See also APPLYSTIFFNESSDAMAGE, ASSEMBLEGLOBALK.

validateModel(model);
EIeff = model.elements.EI .* model.elements.stiffnessFactor;
end

function R = recoverReactions(K, U, F, restrainedDofs)
%RECOVERREACTIONS Support reactions from full-system equilibrium.
%   R = RECOVERREACTIONS(K, U, F, RESTRAINED) returns the column vector
%       R = K*U - F   at the restrained DOFs, and 0 at free DOFs,
%   where K is the unrestrained global stiffness, U the full displacement
%   vector (zeros at restrained DOFs) and F the full applied load vector.
%   Loads applied directly at a restrained DOF therefore pass into the
%   reaction. R uses the global DOF signs: force [N] positive upward and
%   couple [N*m] positive counterclockwise, acting ON the beam FROM the
%   support.
%
%   See also SOLVESTATICMODEL.

nDof = numel(U);
if ~(isequal(size(K), [nDof, nDof]) && numel(F) == nDof)
    error('BridgeFE:invalidInput', ...
        'K must be %d-by-%d and F must have %d entries to match U.', nDof, nDof, nDof);
end
r = restrainedDofs(:);
if any(r < 1 | r > nDof | r ~= round(r))
    error('BridgeFE:invalidInput', 'restrainedDofs must be DOF indices between 1 and %d.', nDof);
end

R = zeros(nDof, 1);
R(r) = full(K(r, :) * U(:) - F(r));
end

function dofMap = elementDofs(conn)
%ELEMENTDOFS Global DOF indices of each element, ordered [v_i theta_i v_j theta_j].
%   DOFMAP = ELEMENTDOFS(CONN) returns an NE-by-4 matrix for the NE-by-2
%   connectivity CONN = [i j]. Node n owns global DOFs 2n-1 (v) and 2n
%   (theta), so row e of DOFMAP is [2i-1, 2i, 2j-1, 2j]. Row e is the
%   "A_e" map from global DOFs to the element DOF vector q_e.
%
%   See also ASSEMBLEGLOBALK.

i = conn(:, 1);
j = conn(:, 2);
dofMap = [2*i - 1, 2*i, 2*j - 1, 2*j];
end

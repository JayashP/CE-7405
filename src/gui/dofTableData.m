function data = dofTableData(x, res)
%DOFTABLEDATA Rows of the Matrices tab DOF table: DOF, node, x, status, F, U, R.
%   DATA = DOFTABLEDATA(X, RES) returns a 2NN-by-7 cell array of strings for the
%   node coordinates X [m] (NN nodes) and a static solution RES (SOLVESTATICMODEL:
%   fields F, U, R and restrainedDofs). F, U and R are printed with '%.6g'
%   through FORMATMATRIXCELLS, so an exact zero, also a negative zero from the
%   solver (MATLAB printed U of theta1 as "-0", V-031), is shown as '0'.
%
%   See also FORMATMATRIXCELLS, DOFLABELS, BRIDGECONDITIONAPP.

x = x(:);
nn = numel(x);
nDof = 2 * nn;
labels = dofLabels(nn);
isRestrained = false(nDof, 1);
isRestrained(res.restrainedDofs) = true;
F = formatMatrixCells(res.F(:), '%.6g');
U = formatMatrixCells(res.U(:), '%.6g');
R = formatMatrixCells(res.R(:), '%.6g');
data = cell(nDof, 7);
for k = 1:nDof
    status = 'free';
    if isRestrained(k)
        status = 'restrained';
    end
    data(k, :) = {labels{k}, sprintf('%d', ceil(k/2)), sprintf('%.4g', x(ceil(k/2))), status, F{k}, U{k}, R{k}};
end
end

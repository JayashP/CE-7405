function ke = beamElementStiffness(EI, Le)
%BEAMELEMENTSTIFFNESS 4x4 Euler-Bernoulli bending stiffness of a 2-node beam element.
%   KE = BEAMELEMENTSTIFFNESS(EI, LE) returns the exact stiffness matrix of a
%   prismatic, horizontal Euler-Bernoulli beam element of flexural rigidity
%   EI and length LE.
%
%   Inputs (internal SI units, DECISIONS.md D-002):
%     EI  flexural rigidity [N*m^2]; real, finite, > 0.
%         Steel: EI = Es*Is.  RCC: EI = Ec*Ieff (user-supplied, constant
%         during a linear analysis). The element does not know the material.
%     LE  element length [m]; real, finite, > 0.
%
%   Output:
%     KE  4-by-4 symmetric matrix. Rows and columns follow the element DOF
%         order q_e = [v1; theta1; v2; theta2] (DECISIONS.md D-003/D-004):
%           v      vertical displacement [m], positive upward
%           theta  rotation [rad], positive counterclockwise (theta = dv/dx)
%         so KE*q_e gives [F1; M1; F2; M2] in [N; N*m; N; N*m] with
%         forces positive upward and couples positive counterclockwise.
%
%         KE = EI/LE^3 * [  12     6*LE    -12     6*LE
%                           6*LE   4*LE^2  -6*LE   2*LE^2
%                          -12    -6*LE     12    -6*LE
%                           6*LE   2*LE^2  -6*LE   4*LE^2 ]
%
%   Local and global axes coincide (horizontal element, T = I). Axial and
%   shear deformations are not modelled.
%
%   Example (E = 200 GPa, I = 0.01 m^4, 1.5 m element):
%     ke = beamElementStiffness(200e9 * 0.01, 1.5);
%
%   See also ASSEMBLEGLOBALK, ELEMENTDOFS.

assertPositiveFiniteScalar(EI, 'EI');
assertPositiveFiniteScalar(Le, 'Le');

ke = (EI / Le^3) * [ 12,     6*Le,    -12,     6*Le;
                     6*Le,   4*Le^2,  -6*Le,   2*Le^2;
                    -12,    -6*Le,     12,    -6*Le;
                     6*Le,   2*Le^2,  -6*Le,   4*Le^2 ];
end

function N = sw_symorder(R, T)
% determine the order of the symmetry operator
%
% N = SW_SYMORDER(R, T) 
%
% It determines the order of the (R,T) symmetry operator, where R is a
% rotation matrix and T is a translation. Maximum order is 10 if the matrix
% is not a rotation matrix of any crystallographic point group.
%
% Input:
%
% R         Rotation matrix, dimensions are [3 3].
% T         Translation vector, dimensions are [3 1] optional.
%
% Example:
%
% R^sw_symorder(R) == eye(3);
%
% See also SW_GENATPOS, SW_BASISMAT.
%

% $Name: SpinW$ ($Version: 2.1$)
% $Author: S. Toth$ ($Contact: sandor.toth@psi.ch$)
% $Revision: 238 $ ($Date: 07-Feb-2015 $)
% $License: GNU GENERAL PUBLIC LICENSE$

if nargin == 0
    help sw_symorder;
    return;
end

if nargin == 1
    T = zeros(3,1);
end

tol = 1e-5;

N  = 1;
RN = R;
TN = T;

while ((norm(RN-eye(3))>tol) || norm(TN)>tol) && (N<10)
    RN = R*RN;
    TN = mod(R*TN+T,1);
    N  = N + 1;
end

end
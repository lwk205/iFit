function [b,sigma] = cumprod(a,dim)
% CUMPROD Cumulative product of elements.
%   P = CUMPROD(A) computes the cumulative product of objects elements along
%   columns. P has the same size as A.
%
%   CUMPROD(A,DIM) operates along axis of rank DIM.
%
% Example: a=iData(peaks); p=cumprod(a); abs(sum(p,0)-9.1739e+16) < 5e11
% Version: $Date$ $Version$ $Author$
% See also iData, iData/plus, iData/sum, iData/prod, iData/cumprod

if nargin < 2, dim=1; end

[b,sigma] = private_sumtrapzproj(a,dim, 'cumprod');

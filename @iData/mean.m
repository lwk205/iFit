function b = mean(a, dim)
% b = mean(s, dim) : mean value of iData object
%
%   @iData/mean function to compute the mean value of objects
%     mean(a,dim) averages along axis of rank dim. If dim=0, mean is done
%       on all axes and the total is returned as a scalar value. 
%       mean(a,1) accumulates on first dimension (columns)
%     mean(a,-dim) averages on all axes except the dimension specified, i.e.
%       the result is the mean projection of a along dimension dim.
%
% input:  a: object or array (iData/array of)
%         dim: dimension to average (int)
% output: s: mean of elements (iData/scalar)
% ex:     c=mean(a);
%
% See also iData, iData/floor, iData/ceil, iData/round, iData/combine, iData/mean

if nargin < 2, dim=1; end
if length(a) > 1
  a = combine(a);
  return
end

s=get(a,'Signal');
[link, label]          = getalias(a, 'Signal');
b=a;
setaxis(b, [], getaxis(b)); % delete all axes
if dim > 0
  s = mean(s, dim);
  ax_index=1;
  for index=1:ndims(a)
    if index ~= dim
      setaxis(b, ax_index, getaxis(a, num2str(index)));
      ax_index = ax_index+1;
    end
  end
  setalias(b,'Signal', s, [mfilename ' of ' label ]);     % Store Signal
elseif dim == 0
  for index=1:ndims(a)
    s = mean(s, index);
  end
  return  % scalar
else  % dim < 0
  % accumulates on all axes except the rank specified
  for index=1:ndims(a)
    if index~=-dim, s = mean(s,index); end
  end
  setaxis(b, 1, getaxis(a, num2str(-dim)));
  setalias(b,'Signal', s, [ 'mean projection of ' label ]);     % Store Signal
end

b = iData_private_history(b, mfilename, b, dim);
s = b;


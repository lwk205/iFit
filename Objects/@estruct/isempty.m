function y = isempty(s)
%  ISEMPTY True for empty object.
%    ISEMPTY(X) returns 1 if X is empty and 0 otherwise. An
%    empty object has no elements.


if numel(s) > 1
  y=[];
  for index = 1:numel(s)
    y(end+1) = isempty(s(index));
  end
  y=reshape(y, size(s));
else 
  y=isempty(fieldnames(s));
end
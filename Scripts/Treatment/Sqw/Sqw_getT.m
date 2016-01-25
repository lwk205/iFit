function  T = Sqw_getT(s)
% Sqw_getT: search for a Temperature value in a data set
%
% input:
%   s: any iData object, including S(q,w) ones.
  
  T = [];
  if isfield(s,'temperature'), T=getfield(s,'temperature'); end
  
  if isempty(T)
    f = findfield(s,'Temperature','exact numeric');
    if ~isempty(f), T = s.(f{1}); end
  end
  
  if isempty(T)
    f = findfield(s,'T','exact numeric');
    if ~isempty(f), T = s.(f{1}); end
  end

  if isempty(T)
    f = findfield(s,'Temperature','numeric');
    if ~isempty(f), T = s.(f{1}); end
  end
  
  if isempty(T)
    f = findfield(s,'T','numeric');
    if ~isempty(f), T = s.(f{1}); end
  end
  
  if isvector(T), T = mean(T(:)); else T=[]; end

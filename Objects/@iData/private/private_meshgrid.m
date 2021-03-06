function [out, needinterp] = private_meshgrid(in, Signal, method)
% PRIVATE_MESHGRID checks/determine an axis system so that 
% * it is regular
% * it matches the Signal dimensions 
%
% input:
%   in:         is a cell array of axes
%   Signal:     array dimensions (as obtained from size), or array which dimensions 
%                 are used for checking axes.
%   method:     can be 'vector' to indicate we want vector axes
%
% output:
%   out:        a cell array of axes which are regular
%   needinterp: true when the Signal needs to be interpolated on new axes

% This file is used by: interp meshgrid

if nargin < 2, Signal=[]; end
if nargin < 3, method=''; end

if isa(in, 'iData')
  if isempty(Signal), Signal = size(in); end
  out = cell(1,ndims(in));
  for index=1:length(out)
    out{index} = getaxis(in, index);  % loads object axes, or 1:end if not defined 
  end
  in = out;
end

needinterp = 0;

% if no Signal is defined, we will determine its size from the axes dimensions
myisvector = @(c)length(c) == numel(c);
if isempty(Signal)
  for index=1:length(in)
    if myisvector(in{index});
      Signal(index) == length(in{index});
    else
      % we assume initial axes are already grid-like, and match the Signal
      Signal = size(in{index}); 
    end
  end
else
  % is Signal already a size ?
  if ~myisvector(Signal) || length(find(Signal>1)) ~= length(in)
    Signal = size(Signal);
  end
end

% check if axes are monotonic (that is their 'unique' values corresponds to the 
% Signal dimensions).
out = in;

% test if all axes are same size, and multi-dimensional (i.e. allready ndgrid)
for index=2:length(in)
  x = in{index};
  if numel(size(x)) == numel(size(in{1})) && any(size(x) ~= size(in{1})),  needinterp=1; end
  if ~isempty(strfind(method, 'vector')) && (numel(x) == prod(Signal) || numel(x) ~= Signal(index))
    needinterp = 1;
  end
end 
if needinterp == 0, return; end

needinterp=0;
for index=1:length(in)
  x = in{index}; 

  x=x(:); ux = unique(x);
  if length(ux) == Signal(index) 
    if numel(x) ~= numel(ux), needinterp=1; end
    % we get a nice vector from the initial axis values
    out{index} = ux; 
  else
    % we use a new regular vector
    out{index} = linspace(min(x), max(x), Signal(index)); 
    needinterp = 1; % new axis requires interpolation
  end
 
end

% make sure we have grid style axes
if isempty(strfind(method, 'vector'))
  [out{:}] = ndgrid(out{:});
end


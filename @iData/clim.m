function a = clim(a, lims)
% b = clim(s,[ cmin cmax ]) : Reduce iData C axis limits
%
%   @iData/clim function to reduce the C axis (rank 4) limits
%     clim(s) returns the current C axis limits. 
%
% input:  s: object or array (iData)
%         limits: new axis limits (vector)
% output: b: object or array (iData)
% ex:     b=clim(a);
%
% Version: $Revision: 1.4 $
% See also iData, iData/plot, iData/ylabel

axisvalues = getaxis(a, 4);
if isempty(axisvalues), return; end
if nargin == 1
  a=[ min(axisvalues) max(axisvalues) ]; 
  return
end

index=find(lims(1) <= axisvalues & axisvalues <= lims(2));
s.type='()';
s.subs={ ':', ':', index };
cmd=a.Command;
a = subsref(a,s);
a.Command=cmd;
a=iData_private_history(a, mfilename, a, lims);

if nargout == 0 & length(inputname(1))
  assignin('caller',inputname(1),a);
end

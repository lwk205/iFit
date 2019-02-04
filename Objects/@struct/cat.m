function Res = cat(A,varargin)
% struct/cat: concatenate structures
%
% Recursively merges fields and subfields of structures A and B to result structure Res
% Simple recursive algorithm merges fields and subfields of two structures
%   Example:
%   A.field1=1;
%   A.field2.subfield1=1;
%   A.field2.subfield2=2;
% 
%   B.field1=1;
%   B.field2.subfield1=10;
%   B.field2.subfield3=30;
%   B.field3.subfield1=1;
% 
%   C=cat(A,B);
%
%  by Igor Kaufman, 02 Dec 2011, BSD
% <http://www.mathworks.com/matlabcentral/fileexchange/34054-merge-structures>

Res=[];
if nargin>0
    Res=A;
end

if nargin > 2
  for index = 1:numel(varargin)
    Res = cat(A, varargin{index});
  end
  return
else B = varargin{1};
end

if nargin==1 || isstruct(B)==0
    return;
end

fnb=fieldnames(B);

for i=1:length(fnb)
   s=char(fnb(i));
   oldfield=[];
   if (isfield(A,s))
       oldfield=getfield(A,s);
   end    
   newfield=getfield(B,s);
   if isempty(oldfield) || isstruct(newfield)==0
     Res=setfield(Res,s,newfield);     
   else
     Res=setfield(Res,s,cat(oldfield, newfield));  
   end    
end    





function y=quadline(varargin)
% y = quadline(p, x, [y]) : Quadratic line
%
%   iFunc/quadline Quadratic fitting function
%     y=p(3)+p(2)*x+p(1)*x.*x;
%
% Reference: http://en.wikipedia.org/wiki/Quadratic_function
%
% input:  p: Quadratic line model parameters (double)
%            p = [ Quadratic Linear Constant ]
%          or 'guess'
%         x: axis (double)
%         y: when values are given and p='guess', a guess of the parameters is performed (double)
% output: y: model value
% ex:     y=quadline([1 1 0], -10:10); or y=quadline('identify') or p=quadline('guess',x,y);
%
% Version: $Date$ $Version$ $Author$
% See also iFunc, iFunc/fits, iFunc/plot, strline, quad2d
% 

y.Name      = [ 'Quadratic equation (1D) [' mfilename ']' ];
y.Parameters={'Quadratic' 'Linear','Constant'};
y.Description='Quadratic equation. Ref: http://en.wikipedia.org/wiki/Quadratic_function';
y.Expression= @(p,x) p(3)+p(2)*x+p(1)*x.*x;

% use ifthenelse anonymous function
% <https://blogs.mathworks.com/loren/2013/01/10/introduction-to-functional-programming-with-anonymous-functions-part-1/>
% iif( cond1, exec1, cond2, exec2, ...)
iif = @(varargin) varargin{2 * find([varargin{1:2:end}], 1, 'first')}();
y.Guess     = @(x,y) iif(...
  ~isempty(y), @() [ polyfit(x(:), y(:), 2) ], ...
  true            , @() [1 1 0]);
  
y.Dimension =1;

y = iFunc(y);

if nargin == 1 && isnumeric(varargin{1})
  y.ParameterValues = varargin{1};
elseif nargin > 1
  y = y(varargin{:});
end


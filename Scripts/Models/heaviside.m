function y=heaviside(varargin)
% y = heaviside(p, x, [y]) : Heaviside function
%
%   iFunc/heaviside Heaviside fitting function
%     y = 0*x+p(4); y(find(x >= p(2))) = p(1);
%   The Width parameter sign indicates if this is a raising (positive) or 
%   falling (negative) Heaviside.
%
% input:  p: Heaviside model parameters (double)
%            p = [ Amplitude Centre FullWidth BackGround ]
%          or 'guess'
%         x: axis (double)
%         y: when values are given and p='guess', a guess of the parameters is performed (double)
% output: y: model value
% ex:     y=heaviside([1 0 1 1], -10:10); or plot(heaviside);
%
% Version: $Revision$
% See also iFunc, iFunc/fits, iFunc/plot

y.Name      = [ 'Heaviside (1D) [' mfilename ']' ];
y.Parameters={'Amplitude','Centre','FullWidth','Background'};
y.Description='Heaviside model. The Width parameter sign indicates if this is a raising (positive) or falling (negative) Heaviside.';
y.Expression= {'signal = zeros(size(x))+p(4);', ...
  'if p(3) >= 0, signal(find(x >= p(2))) = p(1);', ...
  'else signal(find(x <= p(2))) = p(1); end' };
y.Guess     = @(x,signal) [ NaN ...
                            sum(signal(:).*x(:))/sum(signal(:)) ...
                            sqrt(abs(sum(x(:).*x(:).*signal(:))/sum(signal(:)) - sum(signal(:).*x(:))/sum(signal(:))*sum(signal(:).*x(:))/sum(signal(:)))) ...
                            NaN ];

y = iFunc(y);


if length(varargin)
  y = y(varargin{:});
end

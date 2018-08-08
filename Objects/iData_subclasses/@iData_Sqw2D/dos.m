function [DOS, g, fig] = dos(s, method, n)
% iData_Sqw2D: dos: compute the generalised density of states (gDOS) from a S(q,w)
%
% compute: iData_Sqw2D -> generalised Density of States gDOS [p=1]
%
%  The returned generalised density of states corresponds with the 1-phonon term in the
%  the incoherent Gaussian approximation. This density of states is normalised to 1.
%
%       gDOS(q,w) = S(q,w) w^2/q^2                   Bellissent
%       gDOS(q,w) = S(q,w) w  /q^2/[1 + n(hw)]       Carpenter/Price
%  and:
%       gDOS(w)   = lim(q->0) [ gDOS(q,w) ]
%
%       gDOS(q,w) = w*q*S(q,w)/[Qmax^4 - Qmin^4]/(1+n(w)) Bredov/Oskotskii
%       gDOS(w)   = trapz(g, 2)
%
%  The Bredov/Oskotskii methodology provides the best gDOS estimate, using the
%  whole data set.
%
%  LIMITATIONS/WARNINGS:
%  The incoherent approximation states that the gDOS from an incoherent S(q,w) is 
%    roughly equal to that obtained from a coherent S(q,w). However, the 
%    applicability to a coherent dynamic structure factor S(q,w) should be
%    taken with great care, as this formalism then does not fully hold.
%  This implementation is in principle exact for an isotropic monoatomic material,
%    e.g. a liquid, powder, or cubic crystal. 
%  This routine should better be applied on an incoherent dynamic S(q,w) data set.
%
%  The method to use in the gDOS computation can be given as 2nd argument
%       gDOS = dos(Sqw, 'Bredov')         more accurate as it uses 100% of data
%       gDOS = dos(Sqw, 'Carpenter')      Temperature must be a property
%       gDOS = dos(Sqw, 'Bellissent')     simple yet efficient
%
%  The gDOS is stored in the 'gDOS' property of the initial Sqw object, and is 
%    retrieved without recomputation when available. 
%  To force a recomputation of the gDOS, use:
%       dos(Sqw, 'method', 0) or dos(Sqw, 'method', 'force')
%
% References: Price J. et al, Non Cryst Sol 92 (1987) 153
%         Bellissent-Funel et al, J. Mol. Struct. 250 (1991) 213
%         Carpenter and Pelizarri, Phys. Rev. B 12, 2391 (1975)
%         Suck et al, Journal of Alloys and Compounds 342 (2002) 314
%         Bredov et al., Sov. Phys. Solid State 9, 214 (1967)
%         V.S. Oskotskii, Sov. Phys. Solid State 9 (1967), 420.
%         H. Schober, Journal of Neutron Research 17 (2014) 109–357. (esp. p307)
%
% syntax:
%   g = dos(s)
%   g = dos(s, method, n)
%
% input:
%   s:      Sqw data set e.g. 2D data set with w as 1st axis (rows, meV), q as 2nd axis (Angs-1).
%   method: 'Carpenter','Bellissent' or 'Bredov' (default)
%   n:      number of low-angle values to integrate (integer). Default is 10 when omitted.
%           when 0 or 'force', the gDOS is re-computed.
%
% output:
%   g:      gDOS(w)   (1D iData versus energy)
%
% Example: Sqw=iData_Sqw2D('SQW_coh_lGe.nc'); g = dos(Bosify(symmetrize(Sqw))); plot(g);
%
% See also: iData_Sqw2D/multi_phonons, iData_Sqw2D/incoherent
%           iData_vDOS/multi_phonons, iData_vDOS/multi_phonons
% (c) E.Farhi, ILL. License: EUPL.

  DOS=[]; fig = [];
  if nargin < 2, method = []; end
  if nargin < 3, n=[]; end
  
  % handle array of objects
  if numel(s) > 1
    for index=1:numel(s)
      DOS = [ DOS feval(mfilename, s(index), method, n) ];
    end
    if ~isempty(inputname(1))
      assignin('caller',inputname(1),s);
    end
    return
  end

  if strcmp(method, 'force'), method = []; n=0; end
  if isempty(method), method = 'Bredov'; end
  if ~isempty(n) && (strcmp(n, 'force') || (isnumeric(n) && n <= 0))
    s = rmalias(s, 'gDOS');
    n = [];
  end
  if isempty(n), n=10; end
  if isempty(s), return; end
  
  if isfield(s, 'gDOS')
    % access the stored result 9cached)
    DOS = get(s, 'gDOS');
  else
    % do the computation
    % test if classical
    if isfield(s,'classical') || ~isempty(findfield(s, 'classical'))
      if get(s,'classical')
        disp([ mfilename ': WARNING: The data set ' s.Tag ' ' s.Title ' from ' s.Source ])
        disp('  seems to be classical. The DOS computation may be wrong.');
      end
    end
    
    % compute g(q,w) aka P(alpha,beta) -------------------------------------------
    yl=getaxis(s, '1');
    xl=getaxis(s, '2');
    w= getaxis(s,1);
    
    T = Sqw_getT(s);
    if isempty(T) && isempty(strfind(method, 'Bellissent'))
      disp([ mfilename ': WARNING: The data set ' s.Tag ' ' s.Title ' from ' s.Source  ])
      disp(['    has no Temperature defined. Using method=''Bellissent'' as it does not require it.' ])
      method = 'Bellissent';
    end
    
    switch lower(method)
    case {'carpenter','price'}          
      g = sqw_phonon_dos_Carpenter(s, T);  % requires Temperature 
    case {'bredov','oskotskii'}
      g = sqw_phonon_dos_Bredov(s, T);     % requires Temperature
      n = inf;                             % we use all the data.
    otherwise % 'bellissent'
      method = 'Bellissent';
      g = sqw_phonon_dos_Bellissent(s);
    end

    if ischar(xl), setaxis(g,2, xl); end
    if ischar(yl), setaxis(g,1, yl); end

    title(g,[ 'gDOS 2D(' s.Title ') ' method ]);
    if isempty(g.Label), g.Label='gDOS'; end
    
    % this is the weighting for valid data
    S.type='()';
    S.subs={ ~isfinite(g) };
    g = subsasgn(g, S, 0);
    % normalise to 1. No need for the mass, temperature and other constant factors
    sum_g = getaxis(g,0);
    g = g./sum(sum_g(:)); 
    
    % determine the low-momentum limit -------------------------------------------
    s0  = subsref(g,struct('type','.','subs','Signal'));
    DOS = zeros(size(s0,1),1);  % column of g(w) DOS for q->0
    
    if ~isfinite(n) || n<=0
      DOS = sum(s0,2);
    else
      nc  = min(n,size(s0,2));    % get the first n=10 values for each energy transfer
      for i=1:size(s0,1)
        nz = find(isfinite(s0(i,:)) & s0(i,:) > 0, nc, 'first');
        if ~isempty(nz)
          DOS(i) = sum(s0(i,nz));
        end
      end
    end
    DOS=DOS./sum(DOS);
    if isvector(w)
      DOS=iData(w,DOS);
    else
      DOS=iData(w(1,:),DOS);  %^ from meshgrid
    end
    set(DOS,'Error',0);
    DOS.Title = [ 'DOS(' s.Title ') ' method ];
    DOS.Label = [ 'gDOS ' method ];
    title(DOS,[ 'gDOS(' s.Title ') ' method ]);
    xlabel(DOS, 'Energy');
    
    % copy initial aliases and UserData
    DOS.UserData = s.UserData;
    f = getalias(s);
    for index=1:numel(getalias(s))
      if ~isfield(DOS, f{index})
        [link, lab] = getalias(s, f{index});
        DOS = setalias(DOS, f{index}, link, lab);
      end
    end
    
    if numel(getaxis(DOS,1)) ~= prod(size(DOS))
      w = unique(getaxis(s, 1));
      DOS = setaxis(DOS, 1, w);
    end
    
    DOS       = iData_vDOS(DOS);
  end
  
  label(DOS, 0, [  'gDOS [p=1]' '(' label(s, 0) ')' ]);
  DOS = commandhistory(DOS,    'dos', s, method, n);
  
  if nargout == 0 && ~isempty(DOS)
    fig=figure; 
    % plot total DOS
    h=plot(DOS); set(h,'LineWidth',2);
    set(fig, 'NextPlot','new');
  end
  
  setalias(s, 'gDOS', DOS, DOS.Title);
  
  if nargout == 0 & length(inputname(1))
    assignin('caller',inputname(1),s);
  end
  

% ------------------------------------------------------------------------------
function g = sqw_phonon_dos_Carpenter(s, T)
% See e.g.: Boatner et al, PRB 56 (1997) 11584
%           Price J. et al, Non Cryst Sol 92 (1987) 153
%           J. M. Carpenter and C. A. Pelizarri, Phys. Rev. B 12, 2391 (1975)
%
% g(q,w) = exp(2*W) ./ q.^2 * w./(n(w)+1) S(q,w)   [Carpenter]
%
% with:
%   exp(2*W) ~ exp(-0.003*q.^2) ~ 0.9-1 in q=0:5 Angs-1. Assumed to be 1.
%   n(hw) = 1./(exp(w/kT)-1))

  hw= getaxis(s,1); 
  q = getaxis(s,2); 
  beta    = 11.605*hw/T;
  n = 1./(exp(beta) - 1);
  n(~isfinite(n)) = 0;
  
  g       = abs(hw./(n+1)).*s./q.^2;
  set(g,'Error', get(s,'Error')./get(s,'Signal').*get(g,'Signal'));
  
function g = sqw_phonon_dos_Bellissent(s)
% See e.g.: Bellissent-Funel et al, J. Mol. Struct. 250 (1991) 213
%
% uses Carpenter with approx: exp(2W)=1 and 1/(n(w)+1) ~ hw
%
% g(q,w) ~ hw.^2./q.^2 S(q,w)                      [Bellissent]
  hw= getaxis(s,1); 
  q = getaxis(s,2); 
  
  g = s.*hw.^2./q.^2;
  set(g,'Error', get(s,'Error')./get(s,'Signal').*get(g,'Signal'));

function g = sqw_phonon_dos_Bredov(s, T)
% See e.g.: Suck et al, Journal of Alloys and Compounds 342 (2002) 314
%           M. M. Bredov et al., Sov. Phys. Solid State 9, 214 (1967).
%
% g(w) = Ei w./(n(w)+1)/(q_max^4-q_min^4) m/sigma exp(2*W) 
%        * \int_{q_min -> q_max} q / kf DDCS dq
%
%      = w./(n(w)+1)/(q_max^4-q_min^4) m/sigma exp(2*W) * \int_{q_min -> q_max} q S(q,w) dq

% Schober (9.299) p 315
%   \int sin(theta) DDCS d(theta) = sigma ki^2/m exp(-2W(q)) (q^4max-q^4min) g(w) (n+1)/w
%   \int q/ki/kf    DDCS dq
% and (usual Squires exp)
%   DDCS(q,w) = d2sigma/dOmega/dEf = kf/ki sigma S(q,w)

%   \int q/ki/kf kf/ki sigma S(q,w) dq = sigma ki^2/m exp(-2W(q)) (q^4max-q^4min) g(w) (n+1)/w
%   \int q/ki^2 S(q,w) dq = ki^2/m exp(-2W(q)) (q^4max-q^4min) g(w) (n+1)/w
% with fixed Ki:
%   \int q S(q,w) dq = [ exp(-2W(q))/m (q^4max-q^4min)  (n+1)/w ] g(w)
%
% g(w) =  \int q S(q,w) dq / [ exp(-2W(q))/m (q^4max-q^4min)  (n+1)/w ]
%      = [\int q S(q,w) dq] exp(2W(q)) m / (q^4max-q^4min) * w/(1+n)
%      ~ [\int q S(q,w) dq] exp(2W(q)) m w^2/(q^4max-q^4min)

% w/(1+n) ~ w2 to avoid divergence

  % get an estimate of corresponding incident energy
  [s,lambda,distance,chwidth,Ei,Ki] = Sqw_search_lambda(s);
  
  % restrict s to a dynamic range (so that q4 corresponds with a simulated experiment)
  s = dynamic_range(s, Ei);
  
  % re-sample histogram when axes are not vectors
  hist_me = false;
  for index=1:ndims(s)
    x = getaxis(s, index);
    if numel(x) ~= length(x), hist_me=true; break; end
  end
  if hist_me
    s   = hist(s, size(s));  % the data set is well covered here and interpolation works well.
  end
  
  % axes
  w = getaxis(s,1);
  q = getaxis(s,2);

  qSq = s.*q;
  
  % compute delta(Q)
  q4 = zeros(size(w));
  sd = double(s);
  qmax = []; qmin = [];
  for index=1:size(s, 1)
    sw = sd(index,:); % slab for a given energy. length is 'q'
    valid = find(isfinite(sw) & sw > 0);
    if isvector(q)
      qw = q;
    else
      qw = q(index,:);
    end
    q_min = min(qw(valid)); q_max = max(qw(valid));
    if isempty(q_max) || isempty(q_min)
      q_max = inf; q_min = 0;
    end
    qmax(end+1) = q_max;
    qmin(end+1) = q_min;
  end
  qmax = qmax(:); qmin = qmin(:);
  index = find(abs(qmax - qmin) < .1);
  qmax(index) = qmin(index) + 0.1;

  beta    = -11.605*w/T;
  n = 1./(exp(beta) - 1);
  n(~isfinite(n)) = 0;
  g = trapz(q.*s,2).*abs(w./(n+1)./(qmax.^4 - qmin.^4));
  
function q4 = getQ4(s, q, w)
  % getQ4: compute Q4max - Q4min

  % for each energy, we get the min and max which could be measured
  % requires to know the incident energy, but as we normalise g to 1, this is not important
  
  q4= zeros(size(w));
  s = double(s);
  for index=1:size(s, 1)
    sw = s(index,:); % slab for a given energy. length is 'q'
    valid = find(sw(isfinite(sw) & sw > 0));
    if isvector(q)
      qw = q;
    else
      qw = q(index,:);
    end
    q_min = min(qw(valid)); q_max = max(qw(valid));
    if isempty(q_max) || isempty(q_min)
      q_max = nan; q_min = nan;
    end
    if isvector(q)
      q4(index)   = q_max^4 - q_min^4;
    else
      q4(index,:) = q_max^4 - q_min^4;
    end
  end
  
function St = sinDDCSphi(s, lambda)
  % sinDDCSphi: compute the time distribution of the sin theta weighted scattering cross section
  %
  %  The sin(theta) weighted double differential cross section is the input to
  %  e.g. MUPHOCOR and Oskotskii formalism.
  %
  %  The calculation is:
  %    \int sin(theta) DDCS(theta, tof) d(theta)
  %  = \int          q DDCS(q,tof)      dq
  %
  % input:
  %   s: DDCS (q,w) i.e. measurement (including symmetrize, Bosify)
  %   lambda: wavelength(or 2.36 as default) [Angs]
  %
  % output:
  %   St: \int sin(theta) DDCS(theta,tof) d(theta)
  %
  % Example:
  %   s =iData_Sqw2D('D2O_liq_290_coh.sqw.zip'); s=Sqw2ddcs(Bosify(symmetrize(s)));
  %   st=sinDDCSphi(s);
  
  if nargin < 2, lambda=2.36; end
  
  % data must be [\int sin(theta) S(theta,t) dtheta] that is start from time distribution
  % but the computation in q is much faster as we enter a (q,w) data set.
  
  w    = getaxis(s, 1);
  q    = getaxis(s, 2);
  
  SE2V = 437.393377;        % Convert sqrt(E)[meV] to v[m/s]
  V2K  = 1.58825361e-3;     % Convert v[m/s] to k[1/AA]
  K2V  = 1/V2K;
  VS2E = 5.22703725e-6;     % Convert (v[m/s])**2 to E[meV]
  Ki   = 2*pi/lambda;
  Vi   = K2V*Ki;
  Ei   = VS2E*Vi.^2;
  
  Ef   = Ei - w;
  Vf   = sqrt(Ef/VS2E); Vf(Ef<=0) = nan;
  Kf   = Vf/K2V;
  St   = qw2qt(s, lambda);
  set(St, 'Error',   0);
  set(St, 'Monitor', 1); 
  St   = St.*q./Kf;   % Schober Eq (9.294)
  
  clear Ef Vf Kf
  % re-sample histogram when axes are not vectors
  hist_me = false;
  for index=1:ndims(St)
    x = getaxis(St, index);
    if numel(x) ~= length(x), hist_me=true; break; end
  end
  if hist_me
    St   = hist(St, size(St));  % the data set is well covered here and interpolation works well.
  end
  St   = trapz(St, 2); % \int dq
    
function spw = qDDCSKf(s, lambda)
  % sinDDCSphi: compute the energy distribution of the sin theta weighted scattering cross section
  %
  %  The sin(theta) weighted double differential cross section is the input to
  %  e.g. MUPHOCOR and Oskotskii formalism.
  %
  %  The calculation is:
  %    \int sin(theta) DDCS(theta, w) d(theta)
  %  = \int          q DDCS(q,w)      dq
  %
  % input:
  %   s: DDCS (q,w) i.e. measurement (including symmetrize, Bosify and Kf/Ki factor)
  %   lambda: wavelength(or 2.36 as default) [Angs]
  %
  % output:
  %   Spw: \int sin(theta) DDCS(theta,w) d(w)
  
  if nargin < 2, lambda=2.36; end
  
  % data must be [\int sin(theta) S(theta,t) dtheta] that is start from time distribution
  % but the computation in q is much faster as we enter a (q,w) data set.
  
  w    = getaxis(s, 1);
  q    = getaxis(s, 2);
  
  SE2V = 437.393377;        % Convert sqrt(E)[meV] to v[m/s]
  V2K  = 1.58825361e-3;     % Convert v[m/s] to k[1/AA]
  K2V  = 1/V2K;
  VS2E = 5.22703725e-6;     % Convert (v[m/s])**2 to E[meV]
  Ki   = 2*pi/lambda;
  Vi   = K2V*Ki;
  Ei   = VS2E*Vi.^2;
  
  Ef   = Ei - w;
  Vf   = sqrt(Ef/VS2E); Vf(Ef<=0) = nan;
  Kf   = Vf/K2V;
  spw  = copyobj(s);
  set(spw, 'Error',   0);
  set(spw, 'Monitor', 1); 
  spw  = spw.*q./Kf;   % Schober Eq (9.294)
  
  clear Ef Vf Kf
  % re-sample histogram when axes are not vectors
  hist_me = false;
  for index=1:ndims(spw)
    x = getaxis(spw, index);
    if numel(x) ~= length(x), hist_me=true; break; end
  end
  if hist_me
    spw   = hist(spw, size(spw));  % the data set is well covered here and interpolation works well.
  end
  spw   = trapz(spw, 2); % \int dq

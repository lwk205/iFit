function s = Sqw_check(s)
% Sqw_check: check if a 2D iData is aa S(q,w).
%
% conventions:
% omega = Ei-Ef = energy lost by the neutron
%    omega > 0, neutron looses energy, can not be higher than Ei (Stokes)
%    omega < 0, neutron gains energy, anti-Stokes
%
% input:
%   s: Sqw data set
%        e.g. 2D data set with w as 1st axis (rows), q as 2nd axis.

  if isempty(s), return; end
  
  % check if the data set is Sqw (2D)
  w_present=0;
  q_present=0;
  a_present=0;
  t_present=0;
  if isa(s, 'iData') && ndims(s) == 2
    for index=1:2
      lab = lower(label(s,index));
      if isempty(lab), lab=lower(getaxis(s, num2str(index))); end
      if any(strfind(lab, 'wavevector')) || any(strfind(lab, 'momentum')) || strcmp(strtok(lab), 'q') || any(strfind(lab, 'Angs'))
        q_present=index;
      elseif any(strfind(lab, 'energy')) || any(strfind(lab, 'frequency')) || strcmp(strtok(lab), 'w') || any(strfind(lab, 'meV'))
        w_present=index;
      elseif any(strfind(lab, 'time')) || any(strfind(lab, 'sec')) || strcmp(strtok(lab), 't') || strcmp(strtok(lab), 'tof')
        t_present=index;
      elseif any(strfind(lab, 'angle')) || any(strfind(lab, 'deg')) || strcmp(strtok(lab), 't')
        a_present=index;
      end
    end
  end
  if ~w_present && t_present
    % convert from S(xx,t) to S(xx,w): t2e requires L2
    s = Sqw_t2e(s);
    s = Sqw_check(s);
    return
  end
  if ~q_present && a_present && w_present
    % convert from S(phi,w) to S(q,w)
    s = Sqw_phi2q(s);
    s = Sqw_check(s);
    return
  end
  if ~w_present || ~q_present
    disp([ mfilename ': WARNING: The data set ' s.Tag ' ' s.Title ' from ' s.Source ]);
    disp('    does not seem to be an isotropic S(|q|,w) 2D object. Ignoring.');
    s = [];
    return
  end

  % check if we need to transpose the S(q,w)
  if w_present==2 && q_present==1
    s = transpose(s);
  end
  
  % this is the weighting for valid data
  s(~isfinite(s)) = 0;
  
  % check 'classical'
  if isfield(s,'classical') || ~isempty(findfield(s, 'classical'))
    if isfield(s,'classical') classical0 = s.classical;
    else 
      classical0 = findfield(s, 'classical');
      if iscell(classical0), classical0=classical0{1}; end
      classical0 = get(s, classical0);
    end
    if numel(classical0) > 1
      classical0  = classical0(1);
      s.classical = classical0;
    end
  end
  
  w  = s{1};
  % checks that we have 0<w<Ei for Stokes, and w<0 can be lower (anti-Stokes)
  if any(w(:) < 0) && any(w(:) > 0)
    % for experimental data we should get w1=max(w) < Ei and w2 can be as low as
    % measured (neutron gains energy from sample).
    
    
    w1 = max(w(:)); w2 = max(-w(:)); % should have w1 < w2
    if w1 > w2*2
      % we assume the measurement range is at least [-2*Ei:Ei]
      disp([ mfilename ': WARNING: The data set ' s.Tag ' ' s.Title ' from ' s.Source ]);
      disp('    indicates mostly that the energy range is in the positive side.')
      disp('    Check that it corresponds with the neutron loss/sample gain Stokes side');
      disp('    and if not, revert energy axis with e.g. setaxis(s, 1, -s{1})');
    end
  end

  % can we guess if this is classical data ? get temperature ?
  w = s{1};

  if any(w(:) < 0) && any(w(:) > 0)
    % restrict the energy axis to the common +/- range
    w1 = max(w(:)); w2 = max(-w(:)); w_max = min([w1 w2]);

    if w1 ~= w_max || w2 ~= w_max
      s_res  = ylim(s, [-w_max w_max]); % restricted to [-w:w] range
    else
      s_res = s;
    end
    % get axes
    w = s_res{1};
    
    % we compare the s(q,w) and s(q,-w)
    s_opp = setaxis(s_res, 1, -w);
    s_opp = sum(s_opp,2); s_opp = sort(s_opp, 1);

    s_res = sum(s_res,2); s_res = sort(s_res, 1);

    % the ratio should be S(q,w)/S(q,-w) = exp(hw/kT)
    % so log(S(q,w)) - log(S(q,-w)) = hw/kT
    log_s_ratio = log(s_res) - log(s_opp);
    w = log_s_ratio{1};
    clear s_res s_opp
    
    % mean_log_ratio = mean(log_s_ratio,0);
    % std_log_ratio  = std(log_s_ratio,0);
    
    % compute the temperature from the Data
    % log_s_ratio should be a constant if S(q,w) contains Bose
    % then kT = w./log_s_ratio
    T         = w./log_s_ratio*11.6045; % 1 meV = 11.6045 K
    T         = T{0};
    if any(isfinite(T)) && (all(T(~isnan(T))>0.1) || all(T(~isnan(T))<0.1))
      T         = mean(real(T(~isnan(T))));
    else T=NaN;
    end

    if isfinite(T) && T < -0.1
      disp([ mfilename ': WARNING: The data set ' s.Tag ' ' s.Title ' from ' s.Source ]);
      disp([ '    indicates a negative temperature T=' num2str(T) ' K. ' ]);
      disp(  '    Check the definition of the energy: Stokes=neutron losses energy=positive energy side');
      T = Sqw_getT(s);
    end

    % temperature stored ?
    T0        = Sqw_getT(s);
    if isfield(s,'classical') || ~isempty(findfield(s, 'classical'))
      classical0 = s.classical;
      if numel(classical0) > 1
        classical0 = classical0(1);
        s.classical = classical0;
      end
    else
      classical0 = [];
    end

    % log_s_ratio should be about 0 if S(q,w) is symmetric
    classical = [];
    if ~isfinite(T) && ~isnan(T)
      classical = 1;
      T         = Sqw_getT(s);
    elseif T <= 0.1
      classical = 0;
    elseif T > 3000
      classical = 1;
    else 
    end

    % display warnings when mismatch is found
    if ~isempty(classical0) && ~isempty(classical) && classical0 ~= classical
      if   classical0, classical_str='classical/symmetric';
      else             classical_str='experimental/Bose/quantum'; end
      disp([ mfilename ': WARNING: The data set ' s.Tag ' ' s.Title ' from ' s.Source ]);
      disp(['    indicates a ' classical_str ' S(|q|,w) 2D object, but the analysis of the data shows it is not.' ]);
    elseif isempty(classical0) && ~isempty(classical)
      setalias(s,'classical', classical);
    end

    if ~isempty(T0) && ~isempty(T) && ~isnan(T) && ~(0.9 < T/T0 & T/T0 < 1.1)
      disp([ mfilename ': WARNING: The data set ' s.Tag ' ' s.Title ' S(|q|,w) 2D object from ' s.Source ]);
      disp(['    indicates a Temperature T=' num2str(T0) ' [K], but the analysis of the data provides T=' num2str(T) ' [K].' ]);
    end
    if isempty(T0) && ~isempty(T) && ~isnan(T) && T > 0.1 && T < 3000
      disp([ mfilename ': INFO: Setting temperature T=' num2str(T) ' [K] for data set ' s.Tag ' ' s.Title ' S(|q|,w) 2D object from ' s.Source ]);
      s.Temperature = T;
    end
    
  end % energy axis has +/- 

% ------------------------------------------------------------------------------
function s = Sqw_phi2q(s)
% convert S(phi,w) to S(q,w)

  [s,lambda] = Sqw_search_lambda(s);
  if isempty(s), return; end
  
  disp([ mfilename ': ' s.Tag ' ' s.Title ' Converting Axis 2: angle [deg] to wavevector [Angs-1].' ]);
  ei    = 81.805/lambda^2;
  phi   = s{2}; % angle
  hw    = s{1};
  q     = sqrt(2*(2*pi/lambda)^2*(1 + 0.5*hw/ei - sqrt(1 + hw/ei).*cos(phi*pi/180)));
  s{2}  = q;
  
% ------------------------------------------------------------------------------
function s=Sqw_t2e(s, L2)

  [s,lambda] = Sqw_search_lambda(s);
  if isempty(s), return; end

  disp([ mfilename ': ' s.Tag ' ' s.Title ' Converting Axis 1: time [sec] to energy [meV].' ]);
  t = s{1};
  if  all(t> 0 & t < .1)
    % probably in seconds (usually in the range 0 - 1e-2)
    % NOP: time is already OK
  elseif all(t > 0 & t < 100)
    % probably in milli-seconds
    t = t/1000;
  elseif all(t > 0 & t < 100000)
    % probably in micro-seconds
    t = t/1e6;
  else
    disp([ mfilename ': WARNING: ' s.Tag ' ' s.Title ' the time-of-flight Axis 1 seems odd.' ])
    disp('    Check that the time-of-flight is defined as the time from the sample to the detector, in seconds.')
  end
  
  % we search for the elastic peak position (EPP)
  if ~isfield(s, 'Distance')
    disp([ mfilename ': ' s.Tag ' ' s.Title ' undefined sample-detector distance.' ]);
    disp('    Define e.g. s.Distance=<sample-detector distance in m>');
    s = [];
    return;
  end
  
  L2=get(s, 'Distance');
  telast = L2 * lambda/3956.035;  % time from sample to detector elastic signal
  
  Ei = 81.805/lambda^2;
  Ef = Ei*(telast./t).^2;
  dtdE    = t./(2.*Ef)*1e6; % to be consistent with vnorm abs. calc.
  kikf    = sqrt(Ei./Ef);            % all times above calculated in sec.
  hw = Ei - Ef;
  % Average energy scale:
  hw0 = mean(hw,2);

  dtdEkikf = dtdE.*kikf;
  s    = s.*dtdEkikf;
  s{1} = hw0;
  
% ------------------------------------------------------------------------------ 
function [s,lambda] = Sqw_search_lambda(s, lambda)
  % search for the wavelength in the object
  if nargin < 2
    lambda=[];
  end

  % no wavelength defined: search in object
  if isempty(lambda)
    lambda_field=[ findfield(s, 'wavelength') findfield(s, 'lambda')  ];
    if ~isempty(lambda_field), 
      if iscell(lambda_field), lambda_field=lambda_field{1}; end
      lambda = mean(get(s, lambda_field));
      disp([ mfilename ': ' s.Tag ' ' s.Title ' using incident wavelength=' num2str(lambda) ' [Angs] from ' lambda_field ]);
    end
  end
  if isempty(lambda)
    momentum_field=[ findfield(s, 'wavevector') findfield(s, 'momentum') ];
    if ~isempty(momentum_field), 
      if iscell(momentum_field), momentum_field=momentum_field{1}; end
      momentum = mean(get(s, momentum_field));
      lambda=2*pi/momentum;
      disp([ mfilename ': ' s.Tag ' ' s.Title ' using incident wavevector=' num2str(momentum) ' [Angs-1] from ' momentum_field ]);
    end
  end
  if isempty(lambda)
    energy_field = [ findfield(s, 'energy') findfield(s, 'meV')  ];
    if ~isempty(energy_field)
      if iscell(energy_field), energy_field=energy_field{1}; end
      energy = mean(get(s, energy_field));
      disp([ mfilename ': ' s.Tag ' ' s.Title ' using incident energy=' num2str(energy) ' [meV] from ' energy_field ]);
      lambda = sqrt(81.805/energy);
      setalias(s, 'IncidentEnergy', energy, 'Incident Energy [meV]');
    end
  end
  if isempty(lambda)
    disp([ mfilename ': ' s.Tag ' ' s.Title ' undefined incident neutron wavelength/energy.' ]);
    disp('    Define e.g. s.Wavelength=<lambda in Angs> or s.IncidentEnergy=<energy in meV>');
    s = [];
    return
  end
  
  if ~isfield(s, 'Wavelength')
    setalias(s, 'Wavelength', lambda, 'Incident Wavelength [Angs]');
  end
  
  % search for a sample-to-detector distance
  distance_field = [ findfield(s, 'distance') ];
  if ~isempty(distance_field), 
    if iscell(distance_field), distance_field=distance_field{1}; end
    distance = get(s, distance_field);
    disp([ mfilename ': ' s.Tag ' ' s.Title ' using <sample-detector distance> =' num2str(mean(distance(:))) ' [m] from ' distance_field ]);
    if ~isfield(s, 'Distance')
      setalias(s, 'Distance', distance, 'Sample-Detector distance [m]');
    end
  end
    

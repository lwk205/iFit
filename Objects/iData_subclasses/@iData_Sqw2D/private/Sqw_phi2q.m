function s = Sqw_phi2q(s, lambda, a_present, w_present)
% convert S(phi,w) to S(q,w). Requires wavelength

  if isempty(s), return; end
  if nargin < 2, lambda=[]; end
  if nargin < 3, a_present = 2; end
  if nargin < 4, w_present = 1; end
  
  if isempty(lambda)
    [s,lambda] = Sqw_search_lambda(s);
  end
  
  disp([ mfilename ': ' s.Tag ' ' s.Title ' Converting Axis ' num2str(a_present) ' "' label(s, a_present) '": angle [deg] to wavevector [Angs-1].' ]);
  Ei    = 81.805/lambda^2;
  phi   = getaxis(s,  a_present); % angle (assumed to be scattering angle)
  hw    = getaxis(s,  w_present);
  % check for phi range
  if max(abs(phi)) > 90
     % this is angle at the detector phi=2*theta
     phi = phi/2;
  end
  if isvector(hw) && isvector(phi)
    s = meshgrid(s);
    phi   = getaxis(s,a_present); % angle
    hw    = getaxis(s,w_present);
  end
  % we use: cos(phi) = (Ki.^2 + Kf.^2 - q.^2) ./ (2*Ki.*Kf);
  Ei = 81.805/lambda^2; Ki = 2*pi./lambda; 
  Ef = Ei - hw;         Kf = sqrt(Ef/2.0721);
  q  = sqrt(Ki.^2 + Kf.^2 - 2*cos(phi*pi/180).*Ki.*Kf);

  s = setalias(s, 'q', q, 'Wavevector [Angs-1]');
  s = setaxis(s, a_present, 'q');

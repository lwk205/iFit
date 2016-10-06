function [signal, this] = sqw_phonons_template_dho(HKL, t, FREQ, POLAR, is_event, resize_me, Amplitude, Gamma, Bkg, T)
% sqw_phonon_template_dho: code to build signal from DHO's at each mode FREQ, for all HKL locations
%   when POLAR is not empty, the phonon intensity (Q.e)^2 form factor is computed
%   when resize_me is specified [size], the signal is reshaped to it
% Reference: B. Fak, B. Dorner / Physica B 234-236 (1997) 1107-1108
%            H. Schober, J Neut. Res. 17 (2014) 109

% size of 'w' is [ numel(x) numel(t) ]. the energy for which we evaluate the model
if is_event, w = t(:);
else         w = ones(size(FREQ,1),1) * t(:)'; end
signal               = zeros(size(w));
this.UserData.maxFreq= max(FREQ);
nt = numel(t);

% test for unstable modes
wrong_w = numel(find(FREQ(:) < 0 | ~isreal(FREQ(:)) | ~isfinite(FREQ(:))));
if wrong_w, disp([ 'WARNING: found ' num2str(wrong_w) ' negative/imaginary phonon frequencies (' num2str(wrong_w*100/numel(FREQ)) '% of total) in ' this.Name ]); end

% we compute the Q vector in [Angs-1]. Search for the B=rlu2cartesian matrix
UD = this.UserData; B=[];
if isfield(UD, 'reciprocal_cell')
  B = UD.reciprocal_cell;
elseif isfield(UD, 'properties') && isfield(UD.properties, 'reciprocal_cell')
  B = UD.properties.reciprocal_cell;
else
  B = eye(3); % assume cubic, a=b=c=2*pi, 90 deg, a*=2pi/a=1
end
q_cart = B*HKL';
qx=q_cart(1,:); qy=q_cart(2,:); qz=q_cart(3,:);
Q=[ qx(:) qy(:) qz(:) ];  % in Angs-1
clear q_cart qx qy qz HKL

% check if we have everything needed for the intensity estimate: b_coh, positions
b_coh = []; positions = [];
if isfield(UD, 'positions')
  positions = UD.properties;
elseif isfield(UD, 'properties') && isfield(UD.properties, 'positions')
  positions = UD.properties.positions;
end

if isfield(UD, 'b_coh')
  b_coh = UD.b_coh;
elseif isfield(UD, 'properties') && isfield(UD.properties, 'b_coh')
  b_coh = UD.properties.b_coh;
end

if isempty(b_coh)
  if isfield(UD, 'sigma_coh')
    b_coh = UD.b_coh;
  elseif isfield(UD, 'properties') && isfield(UD.properties, 'sigma_coh')
    b_coh = sqrt(abs(UD.properties.sigma_coh)*100/4/pi); % in [fm]
    b_coh = b_coh .* sign(UD.properties.sigma_coh);
  end
end

if isempty(b_coh) && ~isempty(positions)
  disp([ 'WARNING: Unspecified coherent neutron scattering length specification for the material ' ...
    UD.properties.chemical_formula '. Using b_coh=1 [fm] for all atoms (sigma_coh=0.126 barns). ' ...
    'Specify model.UserData.properties.b_coh as a vector with ' num2str(size(positions,1)) ' value(s) in ' this.Name ]);
  b_coh = ones(1, size(positions,1));
end

if isscalar(b_coh) && size(positions,1) > 1
  disp([ 'WARNING: The material ' UD.properties.chemical_formula ...
    ' has ' num2str(size(positions,1)) ...
    ' atoms in the cell, but only one coherent neutron scattering length is defined. ' ...
    'Using the same value for all (may be wrong). ' ...
    'Specify model.UserData.properties.b_coh as a vector in ' this.Name ]);
  b_coh = b_coh * ones(1, size(positions,1));
end

if ~isempty(b_coh) && ~isempty(positions) && numel(b_coh) ~= size(positions,1)
  disp([ 'WARNING: Inconsistent coherent neutron scattering length specification: has ' ...
    num2str(numel(b_coh)) ' but the material ' UD.properties.chemical_formula ' has ' ...
    num2str(size(positions,1)) ' atoms in the cell. Will not compute phonon intensities. ' ...
    'Specify model.UserData.properties.b_coh as a vector in ' this.Name ]);
    b_coh = [];
end

if ~isempty(b_coh)
  this.UserData.properties.b_coh     = b_coh;
  this.UserData.properties.sigma_coh = 4*pi.*b_coh.*b_coh/100;
end

% the Bose factor is negative for w<0, positive for w>0
% (n+1) converges to 0 for w -> -Inf, and to 1 for w-> +Inf. It diverges at w=0
if ~isempty(T) && T > 0, 
  n         = 1./(exp(w/T)-1);
  n(w == 0) = 0;  % avoid divergence
else n=0; end

if Gamma<=0, Gamma=1e-4; end

for index=1:size(FREQ,2)  % loop on modes
  % % size of 'w0' is [ numel(x) numel(t) ]. the energy of the modes (columns) at given x=q (rows)
  % we assume Gamma(w) = Gamma w/w0
  % W0 is the renormalized phonon frequency W0^2 = w0^2+Gamma^2
  Gamma2 = Gamma^2+imag(FREQ(:,index)).^2; % imaginary frequency goes in the damping
  W02    = Gamma2 +real(FREQ(:,index)).^2;
  
  % phonon form factor (intensity) |Q.e|^2
  % POLAR is a set of [xyz] vectors for each atom in the cell POLAR(HKL,mode,atom,xyz)
  % polarisation vectors already contain the 1/mass factor: ASE/phonons.py:band_structure
  % ZQ=|F(Q)|^2=|sum_atom[ bcoh(atom). exp(-WQ) .* (Q.*POLAR(HKL,index,atom,:)) .* exp(-i*Q.*pos(atom)) ]|^2
  ZQ = 1;
  if ~isempty(POLAR) && ~isempty(positions)
    ZQ = 0;
    for atom=1:size(positions,1)
      % one-phonon structure/form factor in a Bravais lattice
      if ~isempty(T) && T > 0
        nw0       = 1./(exp(FREQ(:,index)/T)-1);
        nw0(FREQ(:,index) == 0) = 0;
      else nw0=0; end
      DW = abs(sum(Q.*squeeze(POLAR(:,index,atom,:)),2)).^2./FREQ(:,index).*(2*nw0+1)/2; % DW function, Schober (9.103)
      clear nw0
      DW = exp(-DW);  % Debye-Waller factor
      % one phonon form factor: H. Schober, (9.203)
      if ~isempty(b_coh) && all(b_coh)
        ZQ = ZQ + b_coh(atom) .* DW .* sum(Q.*squeeze(POLAR(:,index,atom,:)),2) .* exp(-i*Q*positions(atom,:)');
      else  % when no b_coh, we only show DW*exp(-iQr)
        ZQ = ZQ + DW .* exp(-i*Q*positions(atom,:)');
      end
    end
    clear DW
    ZQ = abs(ZQ).^2;
  end
  if ~is_event
    if ~isscalar(ZQ), ZQ = ZQ*ones(1,nt); end
    W02    = W02   *ones(1,nt);
    Gamma2 = Gamma2*ones(1,nt);
  end
  % sum-up all contributions to signal
  signal = signal+ (n+1).*ZQ*4.*w.*sqrt(Gamma2)/pi ./ ((w.^2-W02).^2 + 4*w.^2.*Gamma2);
end % for mode index

% Amplitude
if Amplitude
  signal = signal*Amplitude + Bkg;
end
if ~isempty(resize_me) && prod(resize_me) == numel(signal)
  signal = reshape(signal, resize_me); % initial 4D cube dimension = [ size(x) numel(t) ]
end

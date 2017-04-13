function [options, sav] = sqw_phonons_get_forces(options, decl, calc)
% sqw_phonons_get_forces: perform the force estimate using calculator
%   requires atoms.pkl, supercell and calculator, creates the phonon.pkl

  target = options.target;
  
  % determine if the phonon.pkl exists. If so, nothing else to do
  if ~isempty(dir(fullfile(target, 'phonon.pkl')))
    disp([ mfilename ': re-using ' fullfile(target, 'phonon.pkl') ]);
    return
  end
  
  if ismac,      precmd = 'DYLD_LIBRARY_PATH= ;';
  elseif isunix, precmd = 'LD_LIBRARY_PATH= ; '; 
  else           precmd = ''; end

  % init calculator
  if strcmpi(options.calculator, 'GPAW')
    % GPAW Bug: gpaw.aseinterface.GPAW does not support pickle export for 'input_parameters'
    sav = sprintf('ph.calc=None\natoms.calc=None\nph.atoms.calc=None\n');
  else
    sav = '';
  end
  
  % handle accuracy requirement
  if isfield(options.available,'phonopy') && ~isempty(options.available.phonopy) ...
    && options.use_phonopy
    % use PhonoPy
    ph_run = 'ifit.phonon_run_phonopy(ph, single=True)\n';
  elseif isfield(options, 'accuracy') && strcmpi(options.accuracy,'fast')
    % fast (use symmetry operators from spacegroup)
    ph_run = 'ifit.phonons_run(ph, single=True, difference="central")\n'; 
  elseif isfield(options, 'accuracy') && strcmpi(options.accuracy,'very fast')
    % even twice faster, but less accurate (assumes initial lattice at equilibrium)
    ph_run = 'ifit.phonons_run(ph, single=True, difference="forward")\n'; 
  else
    % the default ASE routine: all moves, slower, more accurate
    ph_run = 'ph.run()\n';
  end
  
  if isfield(options, 'accuracy') && (strcmpi(options.accuracy,'fast') || strcmpi(options.accuracy,'very fast'))
    ph_vib = '';  % fast mode: do not compute IR/Raman modes.
  else
    ph_vib = [ ...
    'try:\n' ...
    '  from ase.vibrations import Vibrations\n', ...
    '  vib = Vibrations(atoms)\n', ...
    '  print "Computing molecular vibrations\\n"\n', ...
    '  vib.run()\n', ...
    '  vib.summary()\n' ...
    '  properties["zero_point_energy"] = vib.get_zero_point_energy()\n' ...
    '  properties["vibrational_energies"]=vib.get_energies()\n' ...
    'except:\n' ...
    '  print "Vibrational analysis (IR Raman) failed. Ignoring.\\n"\n' ...
    '  pass\n' ];
  end
  
  displ = options.disp;
  if ~isscalar(displ), displ=0.01*norm(options.disp); end

  % start python --------------------------  
  
  % this scripts should be repeated as long as its return value is null (all is fine)
  options.script_get_forces_iterate = [ ...
    '# python script built by ifit.mccode.org/Models.html sqw_phonons\n', ...
    '# on ' datestr(now) '\n' ...
    '# E. Farhi, Y. Debab and P. Willendrup, J. Neut. Res., 17 (2013) 5\n', ...
    '# S. R. Bahn and K. W. Jacobsen, Comput. Sci. Eng., Vol. 4, 56-66, 2002.\n', ...
    '#\n', ...
    '# Computes the Hellmann-Feynman forces and stores an ase.phonon.Phonons object in a pickle\n', ...
    '# Launch with: python sqw_phonons_iterate.py (and wait...)\n', ...
    'from ase.phonons import Phonons\n', ...
    'import pickle\n', ...
    'import numpy\n', ...
    'import scipy.io as sio\n', ...
    'from os import chdir\n', ...
    'import ifit\n' ...
    'chdir("' target '")\n', ...
    '# Get the crystal and calculator\n', ...
    'fid = open("atoms.pkl","rb")\n' ...
    'atoms = pickle.load(fid)\n' ...
    'fid.close()\n' ...
    decl '\n', ...
    calc '\n', ...
    'atoms.set_calculator(calc)\n' ...
    '# Phonon calculator\n', ...
    sprintf('ph = Phonons(atoms, calc, supercell=(%i, %i, %i), delta=%f)\n',options.supercell, displ), ...
    'ret = ' ph_run, ...
    'fid = open("phonon.pkl","wb")\n' , ...
    'calc = ph.calc\n', ...
    sav, ...
    'pickle.dump(ph, fid)\n', ...
    'fid.close()\n', ...
    'if ret:\n' ...
    '    exit(0)  # a single step was done\n' ...
    'else:\n' ...
    '    exit(1)  # no more steps required\n' ];
    
  options.script_get_forces_finalize = [ ...
    '# python script built by ifit.mccode.org/Models.html sqw_phonons\n', ...
    '# on ' datestr(now) '\n' ...
    '# E. Farhi, Y. Debab and P. Willendrup, J. Neut. Res., 17 (2013) 5\n', ...
    '# S. R. Bahn and K. W. Jacobsen, Comput. Sci. Eng., Vol. 4, 56-66, 2002.\n', ...
    '#\n', ...
    '# Computes the Hellmann-Feynman forces and stores an ase.phonon.Phonons object in a pickle\n', ...
    '# Launch with: python sqw_phonons_finalize.py\n', ...
    'from ase.phonons import Phonons\n', ...
    'import pickle\n', ...
    'import numpy\n', ...
    'import scipy.io as sio\n', ...
    'from os import chdir\n', ...
    'import ifit\n' ...
    'chdir("' target '")\n', ...
    '# Get the crystal and calculator\n', ...
    'fid = open("atoms.pkl","rb")\n' ...
    'atoms = pickle.load(fid)\n' ...
    'fid.close()\n' ...
    decl '\n', ...
    calc '\n', ...
    'fid = open("phonon.pkl","rb")\n' , ...
    'ph = pickle.load(fid)\n' ...
    'fid.close()\n' ...
    'atoms.set_calculator(calc)\n' ...
    'ph.calc=calc\n' ...
    'ph.atoms.calc = calc\n' ...
    '# Read forces and assemble the dynamical matrix\n', ...
    'print "Reading forces..."\n', ...
    'if ph.C_N is None:\n', ...
    '    ifit.phonon_read(ph, acoustic=True, cutoff=None) # cutoff in Angs\n', ...
    'fid = open("phonon.pkl","wb")\n' , ...
    'calc = ph.calc\n', ...
    sav, ...
    'pickle.dump(ph, fid)\n', ...
    'fid.close()\n', ...
    '# save FORCES and phonon object as a pickle\n', ...
    'sio.savemat("FORCES.mat", { "FORCES":ph.get_force_constant(), "delta":ph.delta, "celldisp":atoms.get_celldisp() })\n', ...
    '# additional information\n', ...
    'atoms.set_calculator(calc) # reset calculator as we may have cleaned it for the pickle\n', ...
    'print "Computing properties\\n"\n', ...
    'try:    magnetic_moment    = atoms.get_magnetic_moment()\n', ...
    'except: magnetic_moment    = None\n', ...
    'try:    kinetic_energy     = atoms.get_kinetic_energy()\n', ... 
    'except: kinetic_energy     = None\n', ...
    'try:    potential_energy   = atoms.get_potential_energy()\n',... 
    'except: potential_energy   = None\n', ...
    'try:    stress             = atoms.get_stress()\n', ... 
    'except: stress             = None\n', ...
    'try:    total_energy       = atoms.get_total_energy()\n', ...
    'except: total_energy       = None\n', ...
    'try:    angular_momentum   = atoms.get_angular_momentum()\n', ... '
    'except: angular_momentum   = None\n', ...
    'try:    charges            = atoms.get_charges()\n', ...
    'except: charges            = None\n', ...
    'try:    dipole_moment      = atoms.get_dipole_moment()\n', ... 
    'except: dipole_moment      = None\n', ...
    'try:    momenta            = atoms.get_momenta()\n', ... 
    'except: momenta            = None\n', ...
    'try:    moments_of_inertia = atoms.get_moments_of_inertia()\n', ...
    'except: moments_of_inertia = None\n', ...
    'try:    center_of_mass     = atoms.get_center_of_mass()\n', ...
    'except: center_of_mass     = None\n', ...
    '# get the previous properties from the init phase\n' ...
    'try:\n' ...
    '  fid = open("properties.pkl","rb")\n' ...
    '  properties = pickle.load(fid)\n' ...
    '  fid.close()\n' ...
    'except:\n' ...
    '  properties = dict()\n' ...
    ph_vib, ...
    'properties["magnetic_moment"]  = magnetic_moment\n' ...
    'properties["kinetic_energy"]   = kinetic_energy\n' ...
    'properties["potential_energy"] = potential_energy\n' ...
    'properties["stress"]           = stress\n' ...
    'properties["momenta"]          = momenta\n' ...
    'properties["total_energy"]     = total_energy\n' ...
    'properties["angular_momentum"] = angular_momentum\n' ...
    'properties["charges"]          = charges\n' ...
    'properties["dipole_moment"]    = dipole_moment\n' ...
    'properties["moments_of_inertia"]= moments_of_inertia\n' ...
    'properties["center_of_mass"]   = center_of_mass\n' ...
    '# remove None values in properties\n' ...
    'properties = {k: v for k, v in properties.items() if v is not None}\n' ...
    '# export properties as pickle\n' ...
    'fid = open("properties.pkl","wb")\n' ...
    'pickle.dump(properties, fid)\n' ...
    'fid.close()\n' ...
    '# export properties as MAT\n' ...
    'sio.savemat("properties.mat", properties)\n' ...
  ];
  % end   python --------------------------

  
  
  % moves ----------------------------------------------------------------------
  
  % write the script in the target directory
  fid = fopen(fullfile(target,'sqw_phonons_forces_iterate.py'),'w');
  fprintf(fid, options.script_get_forces_iterate);
  fclose(fid);
  
  % call python script with calculator
  disp([ mfilename ': computing Hellmann-Feynman forces...' ]);
  options.status = 'Starting computation. Script is <a href="sqw_phonons_forces_iterate.py">sqw_phonons_forces_iterate.py</a>';
  sqw_phonons_htmlreport('', 'status', options);
  
  % compute the maximum number of steps
  if ~isempty(fullfile(target, 'properties.mat'))
    properties  = load(fullfile(target, 'properties.mat'));
    if isfield(options, 'accuracy') && strcmpi(options.accuracy,'very fast')
      nb_of_steps = numel(cellstr(properties.chemical_symbols))*3;
    else
      nb_of_steps = numel(cellstr(properties.chemical_symbols))*6; % central difference
    end
    % use that to determine the ETA as in sqw_phon
  else
    nb_of_steps = 0;
  end
  
  result = '';
  st = 0;
  t0 = clock;           % a vector used to compute elapsed/remaining seconds
  move = 1;
  
  while st == 0
    try
      if strcmpi(options.calculator, 'GPAW') && isfield(options,'mpi') ...
        && ~isempty(options.mpi) && options.mpi > 1
        [st, result] = system([ precmd status.mpirun ' -np ' num2str(options.mpi) ' '  status.gpaw ' ' fullfile(target,'sqw_phonons_forces_iterate.py') ]);
      else
        [st, result] = system([ precmd 'python ' fullfile(target,'sqw_phonons_forces_iterate.py') ]);
      end
      disp(result)
      % get how many steps have been computed: name is 'phonon.N[xyz][+-].pckl'
      move_update = dir(fullfile(target,'phonon.*.pckl'));
      if numel(move_update) > move
        move = numel(move_update);
      end
      if move <= nb_of_steps
        % display ETA. There are nb_of_steps steps.
        % up to now we have done 'move' and it took etime(clock, t)
        % time per iteration is etime(clock, t)/move.
        % total time of computation is etime(clock, t)/move*nb_of_steps
        % time remaining is etime(clock, t)/move*(nb_of_steps-move)
        % final time is     t+etime(clock, t)/move*nb_of_steps
        remaining = etime(clock, t0)/move*(nb_of_steps-move);
        hours     = floor(remaining/3600);
        minutes   = floor((remaining-hours*3600)/60);
        seconds   = floor(remaining-hours*3600-minutes*60);
        enddate   = addtodate(now, ceil(remaining), 'second');
        
        options.status = [ 'ETA ' sprintf('%i:%02i:%02i', hours, minutes, seconds) ', ending on ' datestr(enddate) '. move ' num2str(move) '/' num2str(nb_of_steps) ' [' num2str(round(move*100.0/nb_of_steps)) '%]'];
        disp([ mfilename ': ' options.status ]);
        sqw_phonons_htmlreport('', 'status', options);
      end
      move = move+1;
    catch
      disp(result)
      sqw_phonons_error([ mfilename ': failed calling ASE with script ' ...
        fullfile(target,'sqw_phonons_iterate.py') ], options);
      options = [];
      return
    end
  end
  
  % now finalize ---------------------------------------------------------------
  
  % write the script in the target directory
  fid = fopen(fullfile(target,'sqw_phonons_forces_finalize.py'),'w');
  fprintf(fid, options.script_get_forces_finalize);
  fclose(fid);
  
  % call python script with calculator
  disp([ mfilename ': computing Force Matrix and creating Phonon/ASE model.' ]);
  options.status = 'Ending computation. Script is <a href="sqw_phonons_forces_finalize.py">sqw_phonons_forces_finalize.py</a>';
  sqw_phonons_htmlreport('', 'status', options);
  
  try
    if strcmpi(options.calculator, 'GPAW') && isfield(options,'mpi') ...
      && ~isempty(options.mpi) && options.mpi > 1
      [st, result] = system([ precmd status.mpirun ' -np ' num2str(options.mpi) ' '  status.gpaw ' ' fullfile(target,'sqw_phonons_forces_finalize.py') ]);
    else
      [st, result] = system([ precmd 'python ' fullfile(target,'sqw_phonons_forces_finalize.py') ]);
    end
    disp(result)
  catch
    disp(result)
    sqw_phonons_error([ mfilename ': failed calling ASE with script ' ...
      fullfile(target,'sqw_phonons_finalize.py') ], options);
    options = [];
    return
  end
  
  

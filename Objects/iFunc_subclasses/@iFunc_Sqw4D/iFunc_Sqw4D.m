classdef iFunc_Sqw4D < iFunc
  % iFunc_Sqw4D: create an iFunc_Sqw4D from e.g. an iFunc 4D object
  %
  % The iFunc_Sqw4D class is a 4D model holding a S(q,w) dynamic structure factor.
  % The axes are QH,QK,QL [e.g rlu] and Energy [e.g. meV].
  %
  % Example: s=sqw_cubic_monoatomic
  %
  % As the estimate of a 4D S(q,w) model may be computationally intensive, most 
  % methods below evaluate the model, and then derive a quantity as a Data set 
  % (e.g. iData)
  %
  % Useful methods for this iFunc flavour:
  %
  % methods(iFunc_Sqw4D)
  %   all iFunc methods can be used.
  % iFunc_Sqw4D(a)
  %   convert a 4D model [a=iFunc class] into an iFunc_Sqw4D to give access to
  %   the methods below.
  % iFunc_Sqw4D(sqw2d, B_matrix or CIF or COD)
  %   convert a Sqw2D model into a 4D model, taking into account the reciprocal space.
  % plot(a)
  %   plot the band structure and density of states
  % plot3(a)
  %   plot the S(q,w) dispersion in the QH=0 plane in 3D
  % scatter3(a)
  %   plot the S(q,w) dispersion in the QH=0 plane in 3D as coloured points
  % slice(a)
  %   Slice and isosurface volume exploration of the S(q,w) dispersion in the QH=0 plane
  % b = band_structure(a)
  %   Compute the band structure
  % d = dos(a)
  %   Compute the density of states
  % m = max(a)
  %   Evaluate the maximum S(q,w) dispersion energy
  % powder(a)
  %   Compute the powder average of the 4D S(q,w) dispersion
  % publish(a)
  %   Generate a readable document with all results
  % t = thermochemistry(a)
  %   Compute and display thermochemistry quantities
  %
  % input:
  %   can be an iFunc or struct or any set of parameters to generate a Sqw4D object.
  %   when not given an iFunc, the parameters to sqw_phonons are expected.
  %
  % output: an iFunc_Sqw4D object
  %
  % See also: sqw_phonons, sqw_cubic_monoatomic, iFunc

  properties
  end
  
  methods
  
    function obj = iFunc_Sqw4D(varargin)
      % iFunc_Sqw4D: create a Sqw4D model
      %
      %  iFunc_Sqw4D(Sqw2D, B or [abc alpha beta gamma] or 'cif' or 'cod: entry')
      %     convert a Sqw2D model into a Sqw4D. The reciprocal space B matrix can
      %     be specified as a 3x3 matrix, a [a b c alpha beta gamma] vector,
      %     a 'CIF/CFL/ShelX' file, or a COD search (as in read_cif). When absent, 
      %     such information is searched in the original model.
      %  iFunc_Sqw4D(4D iFunc)
      %  iFunc(struct)
      %     convert initial 4D model information into Sqw4D. 
      %
      % See also: read_cif
      obj = obj@iFunc;
      
      if nargin == 0
        m = sqw_cubic_monoatomic('defaults');
      elseif nargin == 1 && isa(varargin{1}, mfilename)
        % already an iFunc_Sqw4D
        m = varargin{1};
      elseif nargin >= 1 && isa(varargin{1}, 'iFunc_Sqw2D')
        % convert from iFunc_Sqw2D with lattice parameters or B matrix
        m = iFunc_Sqw2Dto4D(varargin{:});
      elseif nargin == 1 && isa(varargin{1}, 'iFunc')
        % convert from iFunc
        m = varargin{1};
      elseif nargin == 1 && isa(varargin{1}, 'struct')
        m = iFunc(varargin{1});
      else
        % create new Sqw4D model and convert it to iFunc_Sqw4D
        m = sqw_phonons(varargin{:}); 
      end
      
      % from here, we must have either an iFunc or an iFunc_Sqw4D
      if isa(m, mfilename)
        obj = m; obj.class = mfilename;
        return;
      elseif ~isa(m, 'iFunc')
        error([ mfilename ': the given input ' class(m) ' does not seem to be convertible to iFunc_Sqw4D.' ])
      end
      
      % check if the Sqw4D subclass is appropriate
      flag = false;
      if ndims(m) == 4 % must be S(hkl,w)
        flag = true;
      end
      if ~flag
        error([ mfilename ': the given iFunc model does not seem to be an Sqw4D flavour object.' ])
      end
      
      % transfer properties
      % this is a safe way to instantiate a subclass
      warning off MATLAB:structOnObject
      m = struct(m);
      for p = fieldnames(m)'
        obj.(p{1}) = m.(p{1});
      end
      obj.class = mfilename;
    end % iFunc_Sqw4D constructor
    
    function f = iFunc(self)
      % iFunc_Sqw4D: convert a single iFunc_Sqw4D back to iFunc
      f = iFunc;
      warning off MATLAB:structOnObject
      self = struct(self);
      for p = fieldnames(self)'
        f.(p{1}) = self.(p{1});
      end
      f.class = 'iFunc';
    end
    
    function f = iData(self, varargin)
      % iFunc_Sqw4D: iData: evaluate a 4D Sqw into an iData object
      %
      %   iData(self, p, qh, qk, ql, w)
      
      % check for QH QK QL W grid
      if isempty(varargin),  varargin{end+1} = []; end
      if numel(varargin) <2, varargin{end+1} = linspace(-0.5,0.5,20); end
      if numel(varargin) <3, varargin{end+1} = linspace(-0.5,0.5,21); end
      if numel(varargin) <4, varargin{end+1} = linspace(-0.5,0.5,22)'; end
      if numel(varargin) <5, varargin{end+1} = linspace(0.01,max(self)*1.2,31); end
      s = iFunc(self);
      try
        f = iData(s,varargin{:});
      catch
        f = iData; return
      end
      xlabel(f, 'QH [rlu]');
      ylabel(f, 'QK [rlu]');
      zlabel(f, 'QL [rlu]');
      clabel(f, 'Energy [meV]');
      title(f, self.Name);
      f.UserData = s.UserData;
      if ndims(f) == 4, try; f = iData_Sqw4D(f); end; end
      if ~isempty(inputname(1))
        assignin('caller',inputname(1),self); % update in original object
      end
    end % iData
    
    function [signal, model, ax, name] = feval(self, varargin)
      % iFunc_Sqw4D: feval: evaluate the Model on HKLW grid
      if isempty(varargin)
        [signal, ax] = feval_fast(self, 'linear');
        model = self;
        signal= double(signal);
        name = self.Name;
      else
        % varargin{1} is not empty
        if numel(varargin) <2, varargin{end+1} = linspace(-0.5,0.5,20); end
        if numel(varargin) <3, varargin{end+1} = linspace(-0.5,0.5,21); end
        if numel(varargin) <4, varargin{end+1} = linspace(-0.5,0.5,22)'; end
        if numel(varargin) <5, varargin{end+1} = linspace(0.01,max(self)*1.2,31); end
        [signal, model, ax, name] = feval@iFunc(self, varargin{:});
      end
      
      if ~isempty(inputname(1))
        assignin('caller',inputname(1),model); % update in original object
      end
    end
    
    function [fig, s, k] = plot(self, varargin)
      % iFunc_Sqw4D: plot: plot dispersions along principal axes and vDOS
      %
      %   plot(sqw4d, {kpath, w, options})
      if isempty(varargin), varargin = { 'plot meV' }; end
      [s,k,fig]=band_structure(self, varargin{:});
      if ~isempty(inputname(1))
        assignin('caller',inputname(1),self); % update in original object
      end
    end % plot
    
    function [h, f] = plot3(s, varargin)
      % iFunc_Sqw4D: plot3: plot a 3D view of the dispersions
      %
      %   plot3(sqw4d, {'plot options'})
      %
      %   by default, the view shows the QH=0 representation, i.e. [QK,QL,W] axes.
      %   It is possible to specify the type of 3D projection:
      %
      %   projection          command
      %   --------------------------------------------
      %   [QK,QL,W] QH=0      plot3(sqw4d, ..., 'qh') [default]
      %   [QH,QL,W] QK=0      plot3(sqw4d, ..., 'qk')
      %   [QH,QK,W] QL=0      plot3(sqw4d, ..., 'ql')
      %   [QH,QK,QL] sum(W)   plot3(sqw4d, ..., 'w')  [diffraction]
      f = feval_fast(s, '', varargin{:});
      % plot in 3D
      h = plot3(f, varargin{:});
      if ~isempty(inputname(1))
        assignin('caller',inputname(1),s); % update in original object
      end
    end % plot3
    
    function [h, f] = scatter3(s, varargin)
      % iFunc_Sqw4D: scatter3: plot a 3D scatter view of the dispersions
      %
      %   scatter3(sqw4d, {'plot options'})
      %
      %   by default, the view shows the QH=0 representation, i.e. [QK,QL,W] axes.
      %   It is possible to specify the type of 3D projection:
      %
      %   projection          command
      %   --------------------------------------------
      %   [QK,QL,W] QH=0      scatter3(sqw4d, ..., 'qh') [default]
      %   [QH,QL,W] QK=0      scatter3(sqw4d, ..., 'qk')
      %   [QH,QK,W] QL=0      scatter3(sqw4d, ..., 'ql')
      %   [QH,QK,QL] sum(W)   scatter3(sqw4d, ..., 'w')  [diffraction]
      f = feval_fast(s, '', varargin{:});
      % plot in 3D
      h = scatter3(f, varargin{:});
      if ~isempty(inputname(1))
        assignin('caller',inputname(1),s); % update in original object
      end
    end % scatter3
    
    function [h, f] = slice(s, varargin)
      % iFunc_Sqw4D: slice: plot an editable 3D view of the dispersions
      %
      %   by default, the view shows the QH=0 representation, i.e. [QK,QL,W] axes.
      %   It is possible to specify the type of 3D projection:
      %
      %   projection          command
      %   --------------------------------------------
      %   [QK,QL,W] QH=0      slice(sqw4d, ..., 'qh') [default]
      %   [QH,QL,W] QK=0      slice(sqw4d, ..., 'qk')
      %   [QH,QK,W] QL=0      slice(sqw4d, ..., 'ql')
      %   [QH,QK,QL] sum(W)   slice(sqw4d, ..., 'w')  [diffraction]
      f = feval_fast(s, '', varargin{:});
      % plot in 3D
      h = slice(f, varargin{:});
      if ~isempty(inputname(1))
        assignin('caller',inputname(1),s); % update in original object
      end
    end % slice
  
    % methods for Sqw 4D
    
    % bosify
    % debosify
    % gdos
    % sq
  end % methods
  
end % classdef
  

% private functions used in the class ----------------------------------------



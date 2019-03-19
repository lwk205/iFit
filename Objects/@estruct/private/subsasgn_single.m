function a = subsasgn_single(a, S, val, a0)
% subsasgn_single single level assignment
  if numel(S) ~= 1, error([ mfilename ': only works with a single level reference' ]); end

  default = true;
  switch S.type
  case {'()','.'} % syntax: a('fields') does not follow links (setalias).
                  % syntax: a.('field') follows links (set), can be a compound field.
    if ischar(S.subs) S.subs = cellstr(S.subs); end
    if iscellstr(S.subs)
      % follow links for '.' subsref, not for '()'
      a = set_single(a, S.subs{1}, val, S.type(1)=='.', a0);  % which handles aliases
      default = false;
    end
  case '{}' % syntax: a{axis_rank} set axis value/alias (setaxis)
    if isa(a, 'estruct') && numel(S.subs{1}) == 1 % scalar numeric or char
      a = setaxis(a, S.subs{1}, val); % also set cache.check_requested to true
      default = false;
    end
  end
  if default  % other cases
    a = builtin('subsasgn', a, S, val);
  end

% ----------------------------------------------------------------------------
function s = set_single(s, field, value, follow, s0)
  % set_single set a single field to given value
  % when follow is true, the existing field value is checked for further link
  %   then the initial structure s0 is set again.
  
  if nargin <= 3, follow=true; end
  if nargin <= 4, s0=s; end
  
  if any(strcmp(field, {'Signal','Monitor','Error','Axes'})) && isa(s0, 'estruct')
    s0.Private.cache.check_requested = true;
  end

  % cut the field into pieces with '.' as separator
  if any(field == '.')
    field = textscan(field,'%s','Delimiter','.'); field=field{1};
    typs=cell(size(field)); [typs{:}] = deal('.');
    S = struct('type',typs, 'subs', subs);
  else
    field = cellstr(field);
    S = struct('type','.','subs', field{1});
  end
    
  % use builtin subsasgn for the whole path when 'not follow'
  if ~follow && numel(S) > 1
    s = builtin('subsasgn', s, S, value);
    return
  else
    % now handle each level and test for char/alias value
    if numel(S) > 1 % oh no ! this is again recursive (multi levels)
      s = subsasgn_recursive(s, S, value, s0);
    else
      % single level indeed
      if ~isfield(s, S.subs) % new field ?
        if isa(s, 'estruct')
          s.addprop(S.subs);
        else
          s.(S.subs) = [];  % a normal structure
        end
      end
      % subsasgn is faster than setfield which itself calls subsasgn
      if follow
        % get possible alias
        v = builtin('subsref',s, S);
        if ischar(v) && isfield(s0, strtok(v, '.')) % link exists in original objet ?
          try
            s0 = set_single(s0, v, value, follow); % set link in root object
            % must exit recursive levels
            return
          end
        end
      elseif isempty(value) % && ~follow: set link/alias to empty: remove it
        % empty value
        s = rmfield(s, tok);
        return
      end
      % if ~follow: change value. Calls "s.(tok)=value" i.e. subsasgn
      s = builtin('subsasgn',s, S, value); % set true value/alias (no follow)
    end
  end

function s=Sqw_symmetrize(s)
% Sqw_symmetrize(s): extend the S(|q|,w) in both energy sides
%  The resulting S(q,w) is the combination of S(q,w) and S(q,-w), which
%  is thus symmetric in energy:
%     S(q,w) = S(q,-w)
%
%  The S(q,w) is a dynamic structure factor aka scattering function.
%
%  The incoming data set should NOT contain the Bose factor, that is it
%    should be 'classical'.
%  To obtain a 'classical' S(q,w) from an experiment, use first:
%    Sqw_deBosify(s, T)
%
% The positive energy values in the S(q,w) map correspond to Stokes processes, 
% i.e. material gains energy, and neutrons loose energy when scattered.
%
% input:
%   s:  Sqw data set (classical, often labelled as S*)
%        e.g. 2D data set with w as 1st axis (rows), q as 2nd axis.
% output:
%   s:  S(|q|,w) symmetrised in energy
%
% Example: Sqw_symmetrize(s, 300)
%
% See also: Sqw_Bosify, deBosify, Sqw_dynamic_range, Sqw_total_xs

  % handle array of objects
  if numel(s) > 1
    sqw = [];
    for index=1:numel(s)
      sqw = [ sqw feval(mfilename, s(index)) ];
    end
    s = sqw;
    return
  end

  s = Sqw_check(s); % in private
  if isempty(s), return; end

  % test if classical
  if isfield(s,'classical') || ~isempty(findfield(s, 'classical'))
    if s.classical == 0
      disp([ mfilename ': WARNING: The data set ' s.Tag ' ' s.Title ' from ' s.Source ' does not seem to be classical. It may already contain the Bose factor in which case the symmetrisation may be wrong.' ]);
    end
  end

  % test if the data set has single energy side: much faster to symmetrise
  w = s{1}; % should be a row vector
  if isvector(w) && (all(w(:) >= 0) || all(w(:) <= 0))
    signal = get(s, 'Signal');
    signal=[ signal ; signal ];
    [w,index]=unique([ w ; -w ]);
    s{1}=w;
    s = set(s, 'Signal', signal(index,:));
    s = sort(s, 1);
    return
  end
  
  % create a new object with an opposite energy axis
  s_opp = setaxis(s, 1, -s{1});
  s_opp = sort(s_opp, 1);

  % final object (and merge common area)
  s     = combine(s, s_opp);

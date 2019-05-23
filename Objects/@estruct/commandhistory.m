function [s,fig] = commandhistory(a, fig, varargin)
% COMMANDHISTORY Show the command history of object.
%   COMMANDHISTORY(S) opens a dialogue showing all comands used so far
%   to procuce the current object. The dialogue allows to export the
%   commands as a script.
%
%   C = COMMANDHISTORY(S) returns the current object history, which
%   is equivalent to S.Command
%
%   COMMANDHISTORY(S, 'text') adds an entry to the object command list.
%   The text should better be a comment such as '% blah' or a matlab
%   command.
%
% Version: $Date$ $Version$ $Author$
% See also iData, iData/disp, iData/display

% syntax for CloseRequest callback from the listdlg
if nargin >= 2 && ischar(fig)
  % add a command to the history
  s = history(a, fig, varargin{:});
  return
elseif nargin == 2 && ishandle(fig)
  s = commandhistory_export(fig);
  return
end

% handle input iData arrays
if numel(a) > 1
  s = cell(size(a)); fig=s;
  for index=1:numel(a)
    [s{index},fig{index}] = commandhistory(a(index));
  end
  return
end

s = a.Command;
if nargout == 0 || nargout == 2
  T   = a.Name;
  if isempty(T), T = title(a); end
  if iscell(T) && ~isempty(T),  T=T{1}; end
  if ~ischar(T), T = ''; end
  T   = regexprep(T,'\s+',' '); % remove duplicate spaces
  [fig,ad] = listdlg('ListString', s, 'ListSize',[400 300], ...
    'Name', T , ...
    'PromptString', char(a,'short'), ...
    'OKString','Save all to file...','CancelString','Dismiss', ...
    'CreateMode','normal');

  ad.object = a;
  set(fig,'UserData', ad);
  setappdata(0,ad.tag,ad);
  set(fig, 'closerequestfcn','commandhistory(iData, gcbf); delete(gcbf)');
  selection=[]; ok=0;
end

% ----------------------------------------------------------------------
function s=commandhistory_export(fig)

  ad = get(fig, 'UserData');
  if ~isfield(ad,'button') || ~strcmpi(ad.button, 'ok'), s=[]; return; end
  s = get(ad.listbox,'string');
  if isempty(s), return; end
  a        = ad.object;

  % save all commands to a script file
  [filename, pathname] = uiputfile('*.m', 'Save commands to file', [ 'iFit_' a.Tag '_history' ]);
  if filename == 0, return; end % user press Cancel
  filename = fullfile(pathname, filename);
  [pathname, name, ext] = fileparts(filename); % get name without extension
  [fid, message] = fopen(filename, 'w+');
  if fid == -1    % invalid filename
    warning([mfilename ': Error opening file ' filename ' to save object command history' ]);
    disp(message)
    return
  end

  % assemble the header
  NL = sprintf('\n');
  str = [ '% Matlab script generated by iFit/' class(a) '/commandhistory' NL ...
          '% File: ' filename NL ...
          '%   To use/import data, type "' name '" at the matlab prompt.' NL ...
          '%   You will obtain a structure, or an object (if you have iFit installed).' NL ...
          '%   This script may depend on other objects, which you have to create with similar scripts.' NL ...
          '% Original data: ' NL ...
          '%   class:    ' class(a) NL ...
          '%   variable: ' inputname(1) NL ...
          '%   tag:      ' a.Tag NL ...
          '%   label:    ' a.Label NL ...
          '%   source:   ' a.Source NL ...
          '%' NL ...
          '% Matlab ' version ' m-file ' filename ' saved on ' datestr(now) NL ...
          '%' NL ];

  fprintf(fid, '%s', str);
  for index=1:length(s)
    fprintf(fid, '%s\n', s{index});
  end
  fprintf(fid, '%% End of script %s\n', filename);
  fclose(fid);

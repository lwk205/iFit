function out = openh5(filename)
%OPENH5 Open an HDF5 file, display it
%        and set the 'ans' variable to an iData object with its content

out = iData(filename);
plot(out);

if ~isdeployed
  assignin('base','ans',out);
  ans = out
end

function result=test_iData_contour3

  h= contour3(iData(flow), 'view3');
  close(gcf);
  if ~isempty(h)
    result = [ 'OK     ' mfilename ];
  else
    result = [ 'FAILED ' mfilename ];
  end

function rap = addRun(rap,runtype,name)

% Blank template for a run entry
thisrun.name = name;

% And put into acq_details, replacing a single blank entry if it exists
if numel(rap.acqdetails.([runtype 'runs'])) == 1 && isempty(rap.acqdetails.([runtype 'runs']).name)
    rap.acqdetails.([runtype 'runs']) = thisrun;
else
    if ~contains({rap.acqdetails.([runtype 'runs']).name},name), rap.acqdetails.([runtype 'runs'])(end+1) = thisrun; end
end

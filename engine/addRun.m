function rap = addRun(rap,runtype,name)

% Blank template for a run entry
thisrun.name = name;

% And put into acq_details, replacing a single blank entry if it exists
if numel(rap.acqdetails.([runtype 'run'])) == 1 && isempty(rap.acqdetails.([runtype 'run']).name)
    rap.acqdetails.([runtype 'run']) = thisrun;
else
    if ~contains({rap.acqdetails.([runtype 'run']).name},name), rap.acqdetails.([runtype 'run'])(end+1) = thisrun; end
end

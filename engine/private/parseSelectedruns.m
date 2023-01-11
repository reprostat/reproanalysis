% In the case where selected runs is given as a string of run names
%  (e.g., 'attention eyemovements') this parses them into numeric indices of rap.acqdetails.*run

function rap = parseSelectedruns(rap,runs,subject)

% Check subselected runs
selectedruns = rap.acqdetails.selectedruns;
if isempty(selectedruns) || ischar(selectedruns)
    if isempty(selectedruns) || strcmp(selectedruns,'*')
        % Wildcard, same as empty
        selectedruns=1:numel(runs);
    else
        % Named runs, parse to get numbers
        runnames = textscan(selectedruns,'%s'); runnames = runnames{1};
        selectedruns=[];
        for runname = runnames'
            indRun = find(strcmp({runs.name},runname{1}));
            if isempty(indRun)
                logging.error('Unknown run %s specified in selectedruns field, runs were %s',runname{1},sprintf('%s ',runs.name));
            end;
            selectedruns = [selectedruns indRun];
        end
    end
end

if subject ~= 0
    [~, subjRun] = getNByDomain(rap,getRunType(rap),subject);
    selectedruns = intersect(selectedruns,subjRun);
end

rap.acqdetails.selectedruns = selectedruns;

end

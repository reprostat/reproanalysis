% In the case where selected runs is given as a string of run names
%  (e.g., 'attention eyemovements') this parses them into numeric indices of rap.acqdetails.*run

function rap = parseSelectedruns(rap,runs,subject)

% Check subselected runs
selectedrun = rap.acqdetails.selectedrun;
if ischar(selectedrun)
    if strcmp(selectedrun,'*')
        % Wildcard, same as empty
        selectedrun=1:numel(runs);
    else
        % Named runs, parse to get numbers
        runnames = textscan(selectedrun,'%s'); runnames = runnames{1};
        selectedrun=[];
        for runname = runnames'
            indRun = find(strcmp({runs.name},runname{1}));
            if isempty(indRun)
                logging.error('Unknown run %s specified in selectedrun field, runs were %s',runname{1},sprintf('%s ',runs.name));
            end;
            selectedrun = [selectedrun indRun];
        end
    end
end

if subject ~= 0
    [~, subjRun] = getNByDomain(rap,getRunType(rap),subject);
    selectedrun = intersect(selectedrun,subjRun);
end

rap.acqdetails.selectedrun = selectedrun;

end

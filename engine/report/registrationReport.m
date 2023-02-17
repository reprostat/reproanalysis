% flags as string inputs
%   'addToSummary'

function rap = registrationReport(rap,varargin)

    selFlag = cellfun(@ischar, varargin);

    domain = rap.tasklist.currenttask.domain;
    indices = cell2mat(varargin(~selFlag));
    reportStore = sprintf('sub%d',indices(1));

    % Find out what streams we should normalise
    streamToReport = {rap.tasklist.currenttask.outputstreams.name};
    streamToReport(strcmp(streamToReport,'structural')) = []; % avoid double-reporting structural (see also line 15)
    if ~isempty(getSetting(rap,'diagnostic.streamInd'))
        streamToReport = streamToReport(getSetting(rap,'diagnostic.streamInd'));
    end

    % Compile list of filename patterns to images
    % - we assume (normalised) structural is the default to test against
    imgToReport = {...
            [streamToReport{1} ' to structural'] strjoin(['^diagnostic_.*' spm_file(getFileByStream(rap,domain,indices,'structural','checkHash',false),'basename') '.*\.jpg$'],'') ...
            };
    for s = streamToReport
        imgToReport = [ imgToReport ;...
            {['structural to ' s{1}]} strjoin(['^diagnostic_.*' spm_file(getFileByStream(rap,domain,indices,s{1},'checkHash',false),'basename') '.*\.jpg$'],'') ...
            ];
    end

    % Video?
    fnVideos = cellstr(spm_select('FPList', getPathByDomain(rap,domain,indices),['^diagnostic_.*\.mp4$']));
    if ~isempty(fnVideos{1})
        for fn = fnVideos'
            imgToReport = [imgToReport; ...
                'Video' ['^' spm_file(fn{1},'basename') '\.mp4$'] ...
            ];
        end
    end

    % Add to report
    for r = 1:size(imgToReport,1)
        fdiag = spm_select('FPList', getPathByDomain(rap,domain,indices),imgToReport{r,2});
        addReport(rap,reportStore,'<table><tr><td>');
        addReport(rap,reportStore,['<h4>' imgToReport{r,1} '</h4>']);
        rap = addReportMedia(rap,reportStore,fdiag);
        addReport(rap,reportStore,'</td></tr></table>');
    end

    % Summary - only the first
    if contains(varargin(selFlag),'addToSummary')
        % Initialise task report
        taskReportName = rap.tasklist.currenttask.name;
        if ~isempty(rap.tasklist.currenttask.extraparameters)
            taskReportName = [taskReportName rap.tasklist.main(indTask).extraparameters.rap.directoryconventions.analysisidsuffix];
        end
        if ~any(strcmp(rap.report.norm.tasks,taskReportName))
            rap.report.norm.tasks{end+1} = taskReportName;
            addReport(rap,'norm',['<h2>Task: ' taskReportName '</h2>']);
        end
        addReport(rap,'norm',['<h3>' getTaskDescription(rap,indices,'indices') '</h3>']);
        rap = addReportMedia(rap,'norm',spm_select('FPList', getPathByDomain(rap,domain,indices),imgToReport{1,2}));
    end
end

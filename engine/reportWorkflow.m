% Produces HTML summary of analysis

function reportWorkflow(study,tasksToReport)

    % Switch off verbose logging
    global reproaworker
    ll0 = reproaworker.logLevel;
    reproaworker.logLevel = 1;

    logging.info('Fetching report started...');

    % Obtain study info
    switch class(study)
        case 'struct', rap = study;
        case 'char'
            if exist(fullfile(study,'rap.mat')), load(fullfile(study,'rap.mat'),'rap');
            else logging.error('No rap.mat found in %s',study);
            end
        otherwise, logging.error('First input MUST be the rap structure or the study path.');
    end
    if ~isfield(rap.internal,'matlabversion') % reload processsed rap
        load(fullfile(getPathByDomain(rap,'study',[]),'rap.mat'),'rap')
    end

    % Tasks to report
    if nargin < 2
        tasksToReport = arrayfun(@(t) sprintf('%s_%05d',t.name,t.index), rap.tasklist.main, 'UniformOutput', false);
        doNotCheckInput = false;
    else
        doNotCheckInput = true;
    end
    taskNotIncluded = cellfun(@(t) ~any(strcmp({rap.tasklist.main.name},regexp(t,'[_a-z0-9]*(?=_[0-9]{5})','match')) & ([rap.tasklist.main.index] == str2double(regexp(t,'[0-9]{5}','match')))), tasksToReport);
    if any(taskNotIncluded), logging.error('Task(s) not found in the workflow:%s',sprintf(' %s',tasksToReport{taskNotIncluded})); end
    taskIndices = cellfun(@(t) find(strcmp({rap.tasklist.main.name},regexp(t,'[_a-z0-9]*(?=_[0-9]{5})','match')) & ([rap.tasklist.main.index] == str2double(regexp(t,'[0-9]{5}','match')))), tasksToReport);

    % Init report
    if isfield(rap,'report'), rap = rmfield(rap,'report'); end
    rap.report.style = 'reportstyles.css';
    rap.report.attachment = {};
    rap.prov = reproaProv(rap);
    rap.prov.doNotCheckInput = doNotCheckInput;

    % Main HTMLs and summaries
    rap.report.main.fname=fullfile(rap.prov.studyPath,'report.html'); rap.report.fbase = spm_file(rap.report.main.fname,'basename');
    rap.report.sub0.fname = spm_file(rap.report.main.fname,'suffix','_subjects');
    rap.report.subjDir = fullfile(fileparts(rap.report.main.fname),'report_subjects'); dirMake(rap.report.subjDir);
    rap.report.summaries = {};
    hasFirstlevelMaps = any(contains(tasksToReport,'firstlevelthreshold'));
    if any(contains(tasksToReport,'realign'))
        rap.report.moco.fname = spm_file(rap.report.main.fname,'suffix','_moco');
        rap.report.summaries = [rap.report.summaries; {'moco' 'Motion correction summary'}];
    end
    if any(contains(tasksToReport,'normwrite'))
        rap.report.norm.fname = spm_file(rap.report.main.fname,'suffix','_norm');
        rap.report.norm.tasks = {};
        rap.report.summaries = [rap.report.summaries; {'norm' 'Registration summary'}];
    end
    if hasFirstlevelMaps
        rap.report.con0.fname = spm_file(rap.report.main.fname,'suffix','_firstlevel');
        rap.report.conDir = fullfile(fileparts(rap.report.main.fname),'report_firstlevel'); dirMake(rap.report.conDir);
        rap.report.summaries = [rap.report.summaries; {'con0' 'First-level results'}];
    end
    if any(contains(tasksToReport,'epochs'))
        rap.report.er.fname = spm_file(rap.report.main.fname,'suffix','_meeger');
        rap.report.summaries = [rap.report.summaries; {'er' 'M/EEG epoch summary'}];
    end

    % Initialize HTMLs
    copyfile(fullfile(rap.internal.reproapath,'engine','report',rap.report.style),fullfile(rap.prov.studyPath,rap.report.style));
    rap = addReport(rap,'main','HEAD=aa Report');
    rap = addReport(rap,'sub0','HEAD=Subjects');
    for s = 1:size(rap.report.summaries,1), rap = addReport(rap,rap.report.summaries{s,1},['HEAD=' rap.report.summaries{s,2}]); end

    for k = 1:numel(taskIndices)
        indTask = taskIndices(k);
        taskReportName = tasksToReport{k};
        if ~isempty(rap.tasklist.main(indTask).extraparameters)
            taskReportName = [taskReportName rap.tasklist.main(indTask).extraparameters.rap.directoryconventions.analysisidsuffix];
        end

        % add provenance
        if rap.prov.isValid, rap.prov.addTask(indTask); end

        logging.info('Fetching report for %s...',taskReportName);

        deps = getDependencyByDomain(rap,rap.tasklist.main(indTask).header.domain); % get all instances required by the study (destination domain)
        inRun = contains(rap.tasklist.main(indTask).header.domain,'run');

        for depInd = 1:size(deps,1) % iterate through all instances
            if size(deps,2) == 0
                reportStore = 'main';
            else
                reportStore = sprintf('sub%d',deps(depInd,1));
            end

            % Initialise task report
            if depInd == 1
                rap = addReport(rap,reportStore,['<h2>Task: ' taskReportName '</h2>']);
            end

            % Report for runs (if any)
            if inRun
                if depInd == 1, addReport(rap,reportStore,'<table><tr>'); end % Open session
                addReport(rap,reportStore,'<td valign="top">');
                addReport(rap,reportStore,['<h3>Run: ' getRunName(setCurrenttask(rap,'task',indTask),deps(depInd,2)) '</h3>']);
                if size(deps,2) >= 3 % Sub-run level
                    logging.error('NYI');
%                    descSubSession = strrep(domaintree{3},'_',' '); descSubSession(1) = upper(descSubSession(1));
%                    addReport(rap,reportStore,sprintf('<h4>%s: %d</h4>',descSubSession,dep{d}{2}(3)));
                end
            end

            task = reproaTaskClass(rap,indTask,deps(depInd,:));
            if task.isDone()
                rap = runModule(rap,indTask,'report',deps(depInd,:));
            else
                addReport(rap,reportStore,'<h3>Not finished yet!</h3>');
            end

            % Report for runs (if any)
            if inRun
                addReport(rap,reportStore,'</td>');
                if depInd == size(deps,1), addReport(rap,reportStore,'</tr></table>'); end % Close session
            end
        end
    end

    % Close files
    rap = addReport(rap,'main','EOF');
    rap = addReport(rap,'sub0','EOF');
    for subj = 1:getNByDomain(rap,'subject'), rap = addReport(rap,sprintf('sub%d',subj),'EOF'); end
    for s = 1:size(rap.report.summaries,1), rap = addReport(rap,rap.report.summaries{s,1},'EOF'); end
    if hasFirstlevelMaps
        conReports = fieldnames(rap.report); conReports = conReports(contains(conReports,'con[1-9]','regularExpression',true));
        for con = reshape(conReports,1,[]), rap = addReport(rap,con{1},'EOF'); end
    end

    % Provenance
    rap.prov.serialise();

    % Save AAP structure
    studyPath = rap.prov.studyPath;
    rap = rmfield(rap,'prov'); % save space
    if isOctave
        save('-mat-binary',fullfile(studyPath,'rap_reported.mat'), 'rap');
    else
        save(fullfile(studyPath,'rap_reported.mat'), 'rap','-v7.3');
    end

    % Show report
    if ~isdeployed, web(['file://' rap.report.main.fname]); end

    % Restore log level
    reproaworker.logLevel = ll0;
end

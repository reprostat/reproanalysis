function processWorkflow(rap)

    MINIMUMREQUIREDDISKSPACE = 10; % in GB

    global reproacache;
    global queue;
    reproa = reproacache('reproa');

    logging.info(['REPRODUCIBILITY ANALYSIS ' datestr(now)]);
    logging.info('=============================================================');

    rap.internal.pwd = pwd;
    rap.internal.reproaversion = reproa.version;
    rap.internal.reproapath = reproa.toolPath;
    rap.internal.spmversion = spm('Version');
    rap.internal.spmpath = spm('Dir');
    rap.internal.matlabversion = version;
    rap.internal.matlabpath = matlabroot;

    % Backup
    rap = backupWorkflow(rap);

    % Run initialisation modules (negative index)
    for indTask = 1:numel(rap.tasklist.initialisation)
        switch rap.tasklist.initialisation(indTask).header.domain
            case 'study' % checkparameters, makeanalysisroot
                rap = runModule(rap,-indTask,'doit',[]);
            case 'subject' % NYI
                for subj = 1:getNByDomain(rap,'subject')
                    rap = runModule(rap,-indTask,'doit',subj);
                end
        end
    end

    % Connect modules and save rap
    rap = updateWorkflow(rap);

    % Check disk space
    if isOctave
        jvFile = javaObject('java.io.File',getPathByDomain(rap,'study',[]));
    else
        jvFile = java.io.File(getPathByDomain(rap,'study',[]));
    end
    spaceAvailable = jvFile.getUsableSpace/1024/1024/1024; % in GB
    if spaceAvailable < MINIMUMREQUIREDDISKSPACE, logging.error('Only %f GB of disk space free on analysis drive',spaceAvailable); end

    for command = {'checkrequirements' 'doit'}
        if strcmp(command{1},'doit')
            rap = updateWorkflow(rap);

            % Create queue
            if ~exist(sprintf('%sClass', rap.options.wheretoprocess),'file')
                logging.error('Unknown rap.options.wheretoprocess: %s\n',rap.options.wheretoprocess);
            end
            queue = feval(sprintf('%sClass', rap.options.wheretoprocess),rap);
        end

        for indTask = 1:numel(rap.tasklist.main)
            deps = getDependencyByDomain(rap,rap.tasklist.main(indTask).header.domain); % get all instances required by the study (destination domain)
            switch command{1}
                case 'checkrequirements'
                    % run each module once locally
                    rap = runModule(rap,indTask,command{1},deps(1,:)); % we ran checkrequirements only once
                case 'doit'
                    for depInd = 1:size(deps,1) % iterate through all instances
                        toDo = queue.addTask(indTask,deps(depInd,:));
                        if toDo % if to be run, delete doneflags of dependent tasks
                            if isfield(rap.tasklist.main(indTask).outputstreams,'taskindex') % output to any task
                                for destIndTask = [rap.tasklist.main(indTask).outputstreams.taskindex]
                                    destTaskDomain = rap.tasklist.main(indTask).header.domain
                                    destDeps = getDependencyByDomain(rap,destTaskDomain,rap.tasklist.main(indTask).header.domain,deps(depInd,:)); % get all dependent instances (using reverse-depedency search)
                                    for destDepInd = 1:size(destDeps,1)
                                        fileDetele(fullfile(getPathByDomain(rap,destTaskDomain,destDeps(destDepInd,:),'task',destIndTask),reproacache('doneflag')));
                                    end
                                end
                            end
                        end
                    end
            end
        end

        if strcmp(command{1},'doit')
            queue.runall();
            switch queue.status
                case 'error'
                    logging.error('reproa queue error');
            end
        end
    end
end

function rap = backupWorkflow(rap)
    bcprap.directoryconventions.analysisid = rap.directoryconventions.analysisid;
    bcprap.directoryconventions.analysisidsuffix = rap.directoryconventions.analysisidsuffix;
    bcprap.acqdetails.root = rap.acqdetails.root;

    remotefilesystem = rap.directoryconventions.remotefilesystem;
    if ~strcmp(remotefilesystem,'none')
        bcpraprap.acqdetails.(remotefilesystem).root = rap.acqdetails.(remotefilesystem).root;
    end

    bcprap.acqdetails.selectedruns = rap.acqdetails.selectedruns;

    rap.internal.rap_initial = bcprap;
end

function rap = updateWorkflow(rap)
    rap = buildWorkflow(rap);

    switch rap.directoryconventions.remotefilesystem
        case 'none'
            if isOctave
                save('-mat-binary',fullfile(getPathByDomain(rap,'study',[]),'rap.mat'),'rap');
            else
                save(fullfile(getPathByDomain(rap,'study',[]),'rap.mat'),'rap');
            end

        otherwise
            logging.error('NYI');
    end
end

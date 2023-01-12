% Dependencies are calculated by a set of helper functions - e.g.,
%  deps=aas_dependencytree_allfromtrunk(aap,domain);
%   given a task of domain "domain", return a list of all indices at this
%   level - e.g., for "session", deps= {{'session', [1 1]},{'session', [1
%   2]},{'session', [2,1]}....{'session',[nsubj nsess]}}
%
%  aas_doneflag_getpath_bydomain(aap,domain,indices,k)
%   "domaind" specifies the domain (e.g., session, which branched below subject)
%   "indicies" is an array with the number of parameters required for a
%   given branch level (e.g., 2 parameters, subject & session for a
%   session-level task)
%
%  aas_getdependencies_bydomain(aap,sourcedomain,targetdomain,indices,'doneflaglocations');
%   if a task of domain "targetdomain" and indices "indices" is waiting for
%   a task of a given sourcedomain, the stages it must wait for are
%   returned
%
%  aas_getN_bydomain(aap,domain,[indices])
%   get number of parts to domain
%
%  aas_getdirectory_bydomain(aap,domain.index)
%   get subdirectory name for a single example specified by index of this
%   domain (e.g., 'movie' for session 1)

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
            deps = getDependencyByDomain(rap,rap.tasklist.main(indTask).header.domain);
            switch command{1}
                case 'checkrequirements'
                    % run each module once locally
                    rap = runModule(rap,indTask,command{1},deps(1,:));
                case 'doit'
                    for depInd = 1:size(deps,1)
                        queue.addTask(indTask,deps(depInd,:));
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

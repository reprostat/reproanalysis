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

    global reproa;
    global reproacache;
    global queue;

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
    for k = 1:numel(rap.tasklist.initialisation)
        switch rap.tasklist.initialisation(k).header.domain
            case 'study' % checkparameters, makeanalysisroot
                rap = runModule(rap,-k,'doit',[]);
            case 'subject' % NYI
                for subj = 1:getNByDomain(rap,'subject')
                    rap = runModule(rap,-k,'doit',subj);
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

    % Create queue
    if ~exist(sprintf('%sClass', rap.options.wheretoprocess),'file')
        logging.error('Unknown rap.options.wheretoprocess: %s\n',rap.options.wheretoprocess);
    end
    queue = feval(sprintf('%sClass', rap.options.wheretoprocess),rap);

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

%%% Main task loop
%for mytasks = {'checkrequirements','doit'} %
%    for k=1:length(aap.tasklist.main.module)
%        task=mytasks{1};
%        % allow full path of module to be provided [djm]
%        [~, stagename]=fileparts(aap.tasklist.main.module(k).name);
%        index=aap.tasklist.main.module(k).index;
%
%        if (isfield(aap.schema.tasksettings.(stagename)(index).ATTRIBUTE,'mfile_alias'))
%            mfile_alias=aap.schema.tasksettings.(stagename)(index).ATTRIBUTE.mfile_alias;
%        else
%            mfile_alias=stagename;
%        end
%
%        aap=aas_setcurrenttask(aap,k);
%
%        % retrieve description from module
%        description=aap.schema.tasksettings.(stagename)(index).ATTRIBUTE.desc;
%
%        % find out whether this module needs to be executed once per study, subject or session
%        domain=aap.schema.tasksettings.(stagename)(index).ATTRIBUTE.domain;
%        if strcmp(domain,'*'), domain = 'study'; end % generic modules at checkrequirements -> run once
%
%        % Start setting up the descriptor for the parallel queue
%        clear taskmask
%        taskmask.domain=domain;
%        taskmask.k=k;
%        taskmask.task=task;
%        taskmask.stagename=stagename;
%        taskmask.studypath=aas_getstudypath(aap,aap.directory_conventions.remotefilesystem);
%
%        completefirst=aap.internal.inputstreamsources{k}.stream;
%
%        % What needs to finish depends upon the domain of this stage and
%        % the previous one. So, if both are session level, then the single
%        % session needs to finish the previous stage before the next stage
%        % starts on this session. If the latter is subject level, all of
%        % the sessions must finish.
%        % Now execute the module, and change the 'done' flags if task='doit'
%
%        % Get all of the possible instances (i.e., single subjects, or
%        % single sessions of single subjects) for this domain
%
%        deps=aas_dependencytree_allfromtrunk(aap,domain);
%        for depind=1:length(deps)
%            indices=deps{depind}{2};
%
%            msg='';
%            alldone=true;
%            doneflag=aas_doneflag_getpath_bydomain(aap,domain,indices,k);
%            % When used in aas_log messages, escape backward slashes from windows paths.
%            logsafe_path = strrep(doneflag, '\', '\\');
%
%            % Check whether tasksettings have changed since the last execution,
%            % and if they have, then delete doneflag to trigger re-execution
%            if strcmp(task,'doit') && isfield(aap.options,'checktasksettingconsistency') && aap.options.checktasksettingconsistency && aas_doneflagexists(aap,doneflag)
%                prev_settings = load(strrep(doneflag,'done','aap_parameters')); prev_settings = prev_settings.aap.tasklist.currenttask.settings;
%                new_settings = aap.tasksettings.(aap.tasklist.main.module(k).name)(aap.tasklist.main.module(k).index);
%                if ~aas_checktasksettingconsistency(aap,prev_settings,new_settings)
%                    aas_log(aap,false,sprintf('REDO: Settings of module %s_%05d have changed',...
%                        aap.tasklist.main.module(k).name,aap.tasklist.main.module(k).index));
%                    aas_delete_doneflag_bypath(aap,doneflag);
%                end
%            end
%
%            if aas_doneflagexists(aap,doneflag) && strcmp(task,'doit')
%                msg=[msg sprintf('- done: %s for %s \n',description,logsafe_path)];
%            else
%                alldone=false;
%                switch (task)
%                    case 'checkrequirements'
%                        [aap,resp]=aa_feval_withindices(mfile_alias,aap,task,indices);
%                        if ~isempty(resp)
%                            aas_log(aap,0,['\n***WARNING: ' resp]);
%                        end
%                        taskqueue.aap = aap;
%                    case 'doit'
%                        tic
%                        % before starting current stage, delete done_flag for next one
%                        for k0i=1:length(aap.internal.outputstreamdestinations{k}.stream)
%                            aas_delete_doneflag_bydomain(aap,aap.internal.outputstreamdestinations{k}.stream(k0i).destnumber,domain,indices);
%                        end
%
%                        % work out what needs to be done before we can
%                        % execute this stage
%                        completefirst=aap.internal.inputstreamsources{k}.stream;
%                        tbcf={};
%                        for k0i=1:length(completefirst)
%                            if (completefirst(k0i).sourcenumber>0)
%                                tbcf_deps=aas_getdependencies_bydomain(aap,completefirst(k0i).sourcedomain,domain,indices,'doneflaglocations');
%                                for tbcf_depsind=1:length(tbcf_deps)
%                                    tbcf{end+1}=aas_doneflag_getpath_bydomain(aap,tbcf_deps{tbcf_depsind}{1},tbcf_deps{tbcf_depsind}{2},completefirst(k0i).sourcenumber);
%                                end
%                            end
%                        end
%                        taskmask.tobecompletedfirst=tbcf;
%
%                        % now queue current stage
%                        aas_log(aap,0,sprintf('MODULE %s PENDING: %s for %s',stagename,description,logsafe_path));
%
%                        taskmask.indices=indices;
%                        taskmask.doneflag=doneflag;
%                        taskmask.description=sprintf('%s for %s',description,doneflag);
%                        if isfield(aap.tasklist.currenttask.settings,'qsub') && ...
%    							isfield(aap.tasklist.currenttask.settings.qsub,'localonly') && aap.tasklist.currenttask.settings.qsub.localonly && ...
%                                ~strcmp(aap.options.wheretoprocess,'localsingle')
%                            localtaskqueue.addtask(taskmask);
%                        else
%                            taskqueue.addtask(taskmask);
%                        end
%                end
%            end
%        end
%        if (strcmp(task,'doit'))
%            if (alldone)
%                aas_log(aap,false,sprintf('- done: %s for all %s',description,domain));
%            else
%                if (length(msg)>2)
%                    msg=msg(1:length(msg-2));
%                end
%
%                aas_log(aap,false,msg);
%            end
%            % Get jobs started as quickly as possible - important on AWS as it
%            % can take a while to scan all of the done flags
%            taskqueue.runall(dontcloseexistingworkers, false);
%            if ~isempty(localtaskqueue.jobqueue)
%                localtaskqueue.runall(dontcloseexistingworkers, false);
%            end
%            if ~taskqueue.isOpen, break; end
%        end
%    end
%    switch task
%        case 'checkrequirements'
%            % update map
%            aap = update_aap(aap);
%            taskqueue.aap = aap;
%        case 'doit'
%            % Wait until all the jobs have finished
%            taskqueue.runall(dontcloseexistingworkers, true);
%    end
%end
%
%if taskqueue.isOpen, taskqueue.close; end
%
%% Moved back to python as this thread doesn't have permissions to the queue
%% if (exist('receipthandle','var'))
%%     aas_log(aap,0,sprintf('Have run all jobs, now trying to delete message in queue %s with receipt handle %s.',aaworker.aapqname,receipthandle));
%%     sqs_delete_message(aap,aaworker.aapqname,receipthandle);
%% end
%% aas_log(aap,0,'Message deleted');
%
%if ~taskqueue.fatalerrors
%    if ismethod(taskqueue,'QVClose'), taskqueue.QVClose; end
%
%    if ~isempty(aap.options.email)
%        % In case the server is broken...
%        try
%            aas_finishedMail(aap)
%        catch
%        end
%    end
%
%    if isfield(aap.options,'garbagecollection') && aap.options.garbagecollection
%        aas_garbagecollection(aap,1)
%    end
%end
%
%aa_close(aap);
%
%end
%
%function aap = update_aap(aap)
%global aa
%
%% restore root
%if isfield(aap.tasklist,'currenttask')
%    aap.acq_details.root = aap.internal.aap_initial.acq_details.root;
%    aap.directory_conventions.analysisid = aap.internal.aap_initial.directory_conventions.analysisid;
%    aap.directory_conventions.analysisid_suffix = aap.internal.aap_initial.directory_conventions.analysisid_suffix;
%end
%
%% Create folder (required by aas_findinputstreamsources to save provenance)
%if (strcmp(aap.directory_conventions.remotefilesystem,'none'))
%    aapsavepth=fullfile(aap.acq_details.root,[aap.directory_conventions.analysisid aap.directory_conventions.analysisid_suffix]);
%    aas_makedir(aap,aapsavepth);
%end
%
%% Use input and output stream information in XML header to find
%% out what data comes from where and goes where
%aap=aas_findinputstreamsources(aap);
%
%if ~isfield(aap.tasklist,'currenttask') % Store these initial settings before any module specific customisation
%    aap.internal.aap_initial=aap;
%    aap.internal.aap_initial.aap.internal.aap_initial=[]; % Prevent recursively expanding storage
%else % Restore initial settings
%    initinternal = aap.internal;
%    aap = aap.internal.aap_initial;
%    aap.internal = initinternal;
%    if isfield(aap,'aap'), aap = rmfield(aap,'aap'); end
%end
%
%% Save AAP structure (S3?)
%if (strcmp(aap.directory_conventions.remotefilesystem,'none'))
%    aapsavefn=fullfile(aapsavepth,'aap_parameters');
%    aap.internal.aapversion=aa.Version;
%    aap.internal.aappath=aa.Path;
%    aap.internal.spmversion=spm('Version');
%    aap.internal.spmpath=spm('Dir');
%    aap.internal.matlabversion=version;
%    aap.internal.matlabpath=matlabroot;
%    save(aapsavefn,'aap');
%end
%end
%
%
%function [loopvar]=getparallelparts(aap,stagenum)
%[~, prev_stagename]=fileparts(aap.tasklist.main.module(stagenum).name);
%prev_index=aap.tasklist.main.module(stagenum).index;
%if (isfield(aap.schema.tasksettings.(prev_stagename)(prev_index).ATTRIBUTE,'mfile_alias'))
%    prev_mfile_alias=aap.schema.tasksettings.(prev_stagename)(prev_index).ATTRIBUTE.mfile_alias;
%else
%    prev_mfile_alias=prev_stagename;
%end
%[aap,loopvar]=aa_feval(prev_mfile_alias,aap,'getparallelparts');
%end

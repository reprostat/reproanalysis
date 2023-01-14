function rap = runModule(rap,indTask,command,indices,varargin)

    DONEFLAG = 'done';

    global reproaworker
    global reproacache

    argParse = inputParser;
    argParse.addParameter('reproacache',reproacache,@(x) isa(x,'cacheClass'));
    argParse.addParameter('reproaworker',reproaworker,@(x) isa(x,'workerClass'));
    argParse.parse(varargin{:});

    reproaworker = argParse.Results.reproaworker;
    reproacache = argParse.Results.reproacache;

    if ~isa(reproacache,'cacheClass'), logging.error('Cannot find reproacache. When deployed, reproacache MUST be provided'); end
    if ~isa(reproaworker,'workerClass'), logging.error('Cannot find reproaworker. When deployed, reproaworker MUST be provided'); end

    % load task
    if ~isfield(rap.tasklist,'currenttask'), rap = setCurrenttask(rap,'task',indTask); end
    taskDescription = getTaskDescription(rap,indices);

    % prepare task
    if indTask < 0 % initialisation
        logging.info('INITIALISATION - %s',taskDescription);
    else
        if strcmp(command,'doit')
            taskRoot = getPathByDomain(rap,rap.tasklist.currenttask.domain,indices);

            % create taskfolder and save rap
            dirMake(taskRoot);
            if isOctave
                save('-mat-binary',fullfile(taskRoot,['rap_' rap.tasklist.currenttask.name '.mat']),'rap');
            else
                save(fullfile(taskRoot,['rap_' rap.tasklist.currenttask.name '.mat']),'rap');
            end

            % obtain inputstream
            for s = rap.tasklist.currenttask.inputstreams
                logging.error('NYI');
            end

        end

        logging.info('%s - %s',upper(command),taskDescription);
    end

    % run task
    if ~exist(spm_file(rap.tasklist.currenttask.mfile,'ext','.m'),'file'), logging.error('%s doesn''t appear to be a valid m file?',funcname); end
    ci = num2cell(indices);
    rap = feval(rap.tasklist.currenttask.mfile,rap,command,ci{:});

    % flag done (not for initialisation)
    if (indTask > 0) && strcmp(command,'doit'), fclose(fopen(fullfile(taskRoot,DONEFLAG),'w')); end

    % reset rap
    rap = setCurrenttask(rap);
end

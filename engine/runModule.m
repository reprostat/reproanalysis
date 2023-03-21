function rap = runModule(rap,indTask,command,indices,varargin)

    global reproaworker
    global reproacache

    argParse = inputParser;
    argParse.addParameter('reproacache',reproacache,@(x) isa(x,'cacheClass') || isstruct(x));
    argParse.addParameter('reproaworker',reproaworker,@(x) isa(x,'workerClass') || isstruct(x));
    argParse.parse(varargin{:});

    reproaworker = argParse.Results.reproaworker;
    reproacache = argParse.Results.reproacache;

    % if delpoyed -> load from struct
    if isstruct(reproacache), reproacache = cacheClass(reproacache); end
    if isstruct(reproaworker), reproaworker = workerClass(reproaworker); end

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
                % obtain streams
                if iscell(s.name), s.name = s.name{1}; end
                streamName = strsplit(s.name,'.'); streamName = streamName{end};

                if s.taskindex == -1 % remote
                    logging.error('NYI');
                end

                srcrap = setCurrenttask(rap,'task',s.taskindex);
                deps = getDependencyByDomain(rap,s.streamdomain,rap.tasklist.currenttask.domain,indices);
                for d = 1:size(deps,1)
                    % Source
                    srcStreamPath = getPathByDomain(srcrap,s.streamdomain,deps(d,:));
                    srcStreamPath = readLink(srcStreamPath); % make sure the path is canonical
                    srcStreamDescriptor = fullfile(srcStreamPath,sprintf('stream_%s_outputfrom_%s.txt',streamName,srcrap.tasklist.currenttask.name));
                    srcStream = strsplit(fileRetrieve(srcStreamDescriptor,rap.options.maximumretry,'content'),'\n');
                    srcHash = regexp(srcStream{1},'(?<=(#\t))[0-9a-f]*','match'); srcHash = srcHash{1};
                    srcFile = srcStream(2:end-1); % last is newline

                    % Destination
                    destStreamPath = getPathByDomain(rap,s.streamdomain,deps(d,:));
                    destStreamName = sprintf('stream_%s_inputfrom_%s.txt',streamName,srcrap.tasklist.currenttask.name);
                    if exist(destStreamPath,'dir'), destStreamPath = readLink(destStreamPath); % make sure the path is canonical
                    else, dirMake(destStreamPath);
                    end
                    destStreamDescriptor = fullfile(destStreamPath,destStreamName);

                    logging.info('Input - %s',destStreamName);

                    if exist(destStreamDescriptor,'file')
                        % compare hashes of input at source and destination
                        destHash = regexp(fileRetrieve(destStreamDescriptor,rap.options.maximumretry,'content'),'(?<=(#\t))[0-9a-f]*','match'); destHash = destHash{1};
                        if strcmp(destHash,getHashByFiles(srcFile,'localroot',destStreamPath)) && strcmp(srcHash,destHash), continue;
                        else, logging.warning('\tInput has changed at source - re-copying');
                        end
                    else, logging.warning('\tretrieving');
                    end
                    copyfile(srcStreamDescriptor,destStreamDescriptor);
                    for f = srcFile
                        currDestStreamPath = destStreamPath;
                        subDir = spm_file(f{1},'path');
                        if ~isempty(subDir) % subdirectory detected
                            for d = strsplit(subDir,filesep)
                                currDestStreamPath = fullfile(currDestStreamPath,d{1});
                                dirMake(currDestStreamPath);
                            end
                        end
                        if s.tobemodified || ~rap.options.hardlinks
                            copyfile(fullfile(srcStreamPath,f{1}),fullfile(destStreamPath,f{1}));
                        else
                            if isOctave(), link(fullfile(srcStreamPath,f{1}),fullfile(destStreamPath,f{1}));
                            else
                                if ispc()
                                    shell(sprintf('mklink /H %s %s',fullfile(destStreamPath,f{1}), fullfile(srcStreamPath,f{1})));
                                else
                                    shell(sprintf('ln %s %s', fullfile(srcStreamPath,f{1}),fullfile(destStreamPath,f{1})));
                                end
                            end
                        end
                    end
                end
            end

        end

        logging.info('%s - %s',upper(command),taskDescription);
    end

    % run task
    if ~exist(spm_file(rap.tasklist.currenttask.mfile,'ext','.m'),'file'), logging.error('%s doesn''t appear to be a valid m file?',funcname); end
    ci = num2cell(indices);
    rap = feval(rap.tasklist.currenttask.mfile,rap,command,ci{:});

    % flag done (not for initialisation)
    if (indTask > 0) && strcmp(command,'doit'), fclose(fopen(fullfile(taskRoot,reproacache('doneflag')),'w')); end

    % reset rap
    rap = setCurrenttask(rap);
end

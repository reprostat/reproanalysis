function rap = runModule(rap,indTask,command,indices,varargin)

    global reproaworker
    global reproacache

    argParse = inputParser;
    argParse.addParameter('reproacache',reproacache,@(x) isa(x,'cacheClass') || isstruct(x));
    argParse.addParameter('reproaworker',reproaworker,@(x) isa(x,'workerClass') || isstruct(x) || ischar(x));
    argParse.parse(varargin{:});

    reproaworker = argParse.Results.reproaworker;
    reproacache = argParse.Results.reproacache;

    % if delpoyed -> load from struct
    if isstruct(reproacache), reproacache = cacheClass(reproacache); end
    if isstruct(reproaworker), reproaworker = workerClass(reproaworker); end
    
    % if deployed and MATLAB -> create worker based on ENV
    if ischar(reproaworker)
        txt = getenv('PARALLEL_SERVER_STORAGE_LOCATION');
        indASCII = regexp(txt,'(?<=\%)[0-9A-F]{2}');
        chASCII = char(hex2dec(regexp(txt,'(?<=\%)[0-9A-F]{2}','match')));
        for i = numel(indASCII):-1:1
            txt(indASCII(i)-1:indASCII(i)+1) = chASCII(i);
            txt(indASCII(i):indASCII(i)+1) = '';
        end
        logFile = [fullfile(regexp(txt,'(?<=:[A-Z]*{)[a-zA-Z0-9\./_-]*','match','once'),getenv('PARALLEL_SERVER_TASK_LOCATION')) '_log.txt'];
        reproaworker = workerClass(logFile);
    end

    if ~isa(reproacache,'cacheClass'), logging.error('Cannot find reproacache. When deployed, reproacache MUST be provided'); end
    if ~isa(reproaworker,'workerClass'), logging.error('Cannot find reproaworker. When deployed, reproaworker MUST be provided'); end

    % load task
    if ~isfield(rap.tasklist,'currenttask'), rap = setCurrenttask(rap,'task',indTask); end
    taskDescription = getTaskDescription(rap,indices);

    % prepare task
    if indTask < 0 % initialisation
        logging.info('INITIALISATION - %s',taskDescription);
    else
        logging.info('%s - %s',upper(command),taskDescription);
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
            for indInput = 1:numel(rap.tasklist.currenttask.inputstreams)
                s = rap.tasklist.currenttask.inputstreams(indInput);
                % obtain streams
                if iscell(s.name), s.name = s.name{1}; end
                streamName = strsplit(s.name,'.'); content = '';
                switch numel(streamName)
                    case 3
                        [streamName content] = deal(streamName{2:3});
                    case 2
                        if ~isempty(regexp(streamName{1},'[0-9]{5}')) % first is module
                            streamName = streamName{2};
                        else % first is stream
                            [streamName content] = deal(streamName{1:2});
                        end
                    case 1
                        streamName = streamName{1};
                end
                if ~isempty(content)
                    rap.tasklist.currenttask.inputstreams(indInput).name{1} = streamName;  % remove content specification
                    content = strsplit(content,'-');

                    % content renaming -> contents as rows ->
                    % - Nx1 -> no renaming
                    % - 1x2 -> renaming
                    content = cellfun(@(c) strsplit(c,'~'), content,'UniformOutput',false);
                    content = vertcat(content{:});
                end


                if s.taskindex == -1 % remote
                    logging.error('NYI');
                end

                srcrap = setCurrenttask(rap,'task',s.taskindex);
                deps = getDependencyByDomain(rap,s.streamdomain,rap.tasklist.currenttask.domain,indices);
                for d = 1:size(deps,1)
                    % Source
                    srcStreamPath = getPathByDomain(srcrap,s.streamdomain,deps(d,:));
                    srcStreamDescriptor = fullfile(srcStreamPath,sprintf('stream_%s_outputfrom_%s.txt',streamName,srcrap.tasklist.currenttask.name));
                    srcStream = readStream(srcStreamDescriptor,rap.options.maximumretry);
                    if ~isempty(content), srcStream = rmfield(srcStream,setdiff(fieldnames(srcStream),content(:,1))); end

                    % Destination
                    destStreamPath = getPathByDomain(rap,s.streamdomain,deps(d,:));
                    destStreamName = sprintf('stream_%s_inputfrom_%s.txt',streamName,srcrap.tasklist.currenttask.name);
                    if ~exist(destStreamPath,'dir'), dirMake(destStreamPath); end
                    destStreamDescriptor = fullfile(destStreamPath,destStreamName);

                    logging.info('Input - %s',destStreamName);

                    % Check hashes at source
                    if rap.options.checkinputstreamconsistency
                        srcHash = cellfun(@(f) srcStream.(f).hash, fieldnames(srcStream),'UniformOutput',false);
                        fileHash = cellfun(@(f) getHashByFiles(srcStream.(f).files,'localroot',srcStreamPath), fieldnames(srcStream),'UniformOutput',false);
                        if ~all(strcmp(srcHash,fileHash))
                            logging.error('\tInput has changed at source %s.\n\tMake sure that destination module(s) specifies input with tobemodified="1"',srcrap.tasklist.currenttask.name);
                        end
                    end

                    % Compare hashes of input at source and destination
                    if exist(destStreamDescriptor,'file')
                        destStream = readStream(destStreamDescriptor,rap.options.maximumretry);
                        destHash = cellfun(@(f) destStream.(f).hash, fieldnames(srcStream),'UniformOutput',false);
                        try fileHash = cellfun(@(f) getHashByFiles(srcStream.(f).files,'localroot',destStreamPath), fieldnames(srcStream),'UniformOutput',false);
                        catch, fileHash = repmat({''},size(destHash));
                        end
                        if all(strcmp(destHash,fileHash)) && all(strcmp(srcHash,destHash)), continue;
                        else, logging.warning('\tInput cannot be found or has changed - re-copying');
                        end
                    else, logging.info('\tretrieving');
                    end

                    % Copy stream
                    if ~isempty(content) % re-create stream
                        if size(content,2) == 2 % content renaming
                            for c = 1:size(content,1)
                                newStream.(content{c,2}) = srcStream.(content{c,1});
                            end
                            srcStream = newStream;
                        end
                        jsonwrite(destStreamDescriptor,srcStream);
                    else
                        copyfile(srcStreamDescriptor,destStreamDescriptor);
                    end

                    % Copy files
                    srcFile = cellfun(@(f) srcStream.(f).files, fieldnames(srcStream),'UniformOutput',false);
                    for f = vertcat(srcFile{:})'
                        currDestStreamPath = destStreamPath;
                        subDir = spm_file(f{1},'path');
                        if ~isempty(subDir) % subdirectory detected
                            for d = strsplit(subDir,filesep)
                                currDestStreamPath = fullfile(currDestStreamPath,d{1});
                                dirMake(currDestStreamPath);
                            end
                        end
                        if exist(fullfile(destStreamPath,f{1}),'file'), delete(fullfile(destStreamPath,f{1})); end
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
    end

    % run task
    if ~exist(spm_file(rap.tasklist.currenttask.mfile,'ext','.m'),'file'), logging.error('%s doesn''t appear to be a valid m file?',rap.tasklist.currenttask.mfile); end
    ci = num2cell(indices);
    t0 = datetime;
    rap = feval(rap.tasklist.currenttask.mfile,rap,command,ci{:});
    eTime = char(datetime-t0);

    % flag done (not for initialisation)
    if (indTask > 0) && strcmp(command,'doit')
        fid = fopen(fullfile(taskRoot,reproacache('doneflag')),'w');
        fprintf(fid,eTime);
        fclose(fid);
    end

    % reset rap
    rap = setCurrenttask(rap);
end

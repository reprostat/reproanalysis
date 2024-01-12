
classdef batchClass < queueClass
    properties % (Access = private)
        pool
        taskFlags % 0 - in queue; job.ID - submitted; -inf - finished; -1 error
        updateTime = 10 % s to wait between job submissions
        waitBeforeNext = 60 % s to wait when no task or worker is available
    end

    properties (Dependent)
        numWorkers
    end

    methods
        function this = batchClass(rap)
            this = this@queueClass(rap);

            poolProfile = strsplit(rap.directoryconventions.poolprofile,':');
            if ispc()
                if numel(poolProfile{1}) == 1 % pool profile is a full path
                    poolProfile{1} = strjoin(poolProfile(1:2),':');
                    poolProfile(2) = [];
                end
                if isOctave()
                    poolProfile{1} = 'local_PS';
                else
                    poolProfile{1} = 'local';
                end
            elseif ismac()
                logging.error('NYI');
            end
            
            if isOctave()
                this.pool = poolClass(poolProfile{1});
                logging.info('pool %s is detected',this.pool.type);
                if numel(poolProfile) > 1, this.pool.submitArguments = poolProfile{2}; end

                this.pool.numWorkers = rap.options.parallelresources.numberofworkers;
                this.pool.reqMemory = rap.options.parallelresources.memory;
                this.pool.reqWalltime = rap.options.parallelresources.walltime;
                this.pool.jobStorageLocation = this.queueFolder;
            else
                this.pool = parcluster(poolProfile{1});
                logging.info('pool %s is detected',this.pool.Type);
                this.pool.JobStorageLocation = this.queueFolder;
                switch class(this.pool)
                    case 'parallel.cluster.Local'
                        this.pool.NumWorkers = rap.options.parallelresources.numberofworkers;
                    otherwise
                        logging.error('NYI');
                end
            end            
        end

        function val = get.numWorkers(this)
            if isOctave()
                val = this.pool.numWorkers;
            else
                val = this.pool.NumWorkers;
            end
        end

        % Run all tasks on the queue using batch
        function this = runall(this)
            this.taskFlags = zeros(1,numel(this.taskQueue));

            global reproacache

            while ~all(this.taskFlags == -inf)
                this.pStatus = this.STATUS('running');

                % Ready and still in queue
                nextTaskIndices = find(cellfun(@(t) t.isNext(), this.taskQueue) & (this.taskFlags == 0));

                toWait = false;
                if isempty(nextTaskIndices)
                    logging.info('There is no available task -> wait for 60s');
                    toWait = true;
                end

                if isOctave()
                    nAvailableWorkers = this.pool.numWorkers - this.pool.getJobState('running') - this.pool.getJobState('pending');
                else
                    nAvailableWorkers = this.pool.NumWorkers - sum(arrayfun(@(j) any(strcmp(j.State,{'queued', 'pending', 'running'})), this.pool.Jobs));
                end
                if nAvailableWorkers == 0
                    logging.info('There is no available worker -> wait for 60s');
                    toWait = true;
                end

                % Submit tasks
                for i = nextTaskIndices(1:min([numel(nextTaskIndices) nAvailableWorkers]))
                    task = this.taskQueue{i};
                    if isOctave()
                        j = batch(this.pool,@runModule,1,{this.rap task.indTask 'doit' task.indices 'reproacache' struct(reproacache) 'reproaworker' '$thisworker'},...
                              'name',task.name,...
                              'additionalPaths',this.getAdditionalPaths(),...
                              'additionalPackages',reproacache('octavepackages'));
                        this.taskFlags(i) = j.id;
                    else
                        j = batch(this.pool,@runModule,1,{this.rap task.indTask 'doit' task.indices 'reproacache' struct(reproacache) 'reproaworker' '$thisworker'},...                              
                              'AutoAttachFiles', false, ...
                              'AutoAddClientPath', false, ...
                              'AdditionalPaths', this.getAdditionalPaths(),...
                              'CaptureDiary', true);
                        this.taskFlags(i) = j.ID;
                    end
                    this.reportTasks('submitted',i);                    

                    pause(this.updateTime);
                end

                % Wait before checking
                if toWait, pause(this.waitBeforeNext-this.updateTime); end

                % Monitor jobs
                if isOctave()
                    jobState = cellfun(@(j) {j.id j.state}, this.pool.jobs(cellfun(@(j) ismember(j.id,this.taskFlags), this.pool.jobs)), 'UniformOutput',false);
                else
                    jobState = arrayfun(@(j) {j.ID j.State}, this.pool.Jobs(arrayfun(@(j) ismember(j.ID,this.taskFlags), this.pool.Jobs)), 'UniformOutput',false);
                end
                jobState = cat(1,jobState{:});

                if ~any(cellfun(@(s) any(strcmp(s,{'finished' 'error'})), jobState(:,2)))
                    logging.info('All tasks are running');
                    continue;
                end

                % Monitor reproa tasks
                % done
                %   - submitted % isDone
                % failed
                %   - submitted & error/failed
                %   - submitted & ~isDone & finished
                doneTask = arrayfun(@(t) this.taskFlags(t)>0 && this.taskQueue{t}.isDone(), 1:numel(this.taskFlags));
                failedTask = arrayfun(@(t) this.taskFlags(t)>0 && ...
                                           (any(strcmp(jobState{[jobState{:,1}] == this.taskFlags(t),2},{'failed','error'})) || ...
                                            (strcmp(jobState{[jobState{:,1}] == this.taskFlags(t),2},'finished') && ~this.taskQueue{t}.isDone())), ...
                                      1:numel(this.taskFlags));

                % Report reproa tasks
                this.taskFlags(doneTask) = -Inf;
                this.reportTasks('finished',find(doneTask));
                if any(failedTask)
                    this.reportTasks('failed',find(failedTask));
                    % - detailed report
                    for jID = this.taskFlags(failedTask)
                        if isOctave()
                            safeTaskPath = strrep(fullfile(this.pool.jobStorageLocation, this.pool.jobs{jID}.name,this.pool.jobs{jID}.tasks{1}.name),'\','\\');
                            msg = sprintf('Job%d on %s had an error: %s\n',jID,safeTaskPath,this.pool.jobs{jID}.tasks{1}.errorMessage);
                            error = this.pool.jobs{jID}.tasks{1}.error;
                            if ~isempty(error)
                                for e = 1:numel(error.stack)
                                    msg = [msg sprintf('in %s (line %d)\n', ...
                                        strrep(error.stack(e).file,'\','\\'), error.stack(e).line)];
                                end
                            end
                        else
                            safeTaskPath = strrep(fullfile(this.pool.JobStorageLocation, this.pool.Jobs(jID).Name),'\','\\');
                            msg = sprintf('Job%d on %s had an error: %s\n',jID,safeTaskPath,this.pool.Jobs(jID).Tasks(1).ErrorMessage);
                            error = this.pool.Jobs(jID).Tasks(1).Error;
                            if ~isempty(error)
                                for e = 1:numel(error.stack)
                                    msg = [msg sprintf('<a href="matlab: opentoline(''%s'',%d)">in %s (line %d)</a>\n', ...
                                        strrep(error.stack(e).file,'\','\\'), error.stack(e).line,...
                                        strrep(error.stack(e).file,'\','\\'), error.stack(e).line)];
                                end

                            end
                        end
                        if isempty(error)
                            msg = [msg 'No error file has been generated.'];
                        end
                        logging.info([msg '\n']);
                    end
                    break;
                end
            end
            if ~strcmp(this.status,'error')
                this.pStatus = this.STATUS('finished');
                logging.info('Task queue is finished!');
            end
            this.close(false);
        end

        function close(this,doCloseJobs)
            if nargin < 2 || doCloseJobs
                logging.info('Cancelling jobs...');
                if isOctave()
                    cellfun(@(j) j.cancel(), this.pool.jobs);
                else
                    arrayfun(@(j) j.cancel(), this.pool.Jobs);
                end
            end
            close@queueClass(this);
        end

        function p = getAdditionalPaths(this)
            global reproacache

            % reproa
            reproa = reproacache('reproa');
            p = reshape(reproa.toolInPath,[],1);

            % toolboxes
            for tbx = reproa.toolboxes
                if strcmp(tbx{1}.status, 'loaded')
                    p = [reshape(tbx{1}.toolInPath,[],1); p];
                    modDir = fullfile(reproa.toolPath,'external','toolboxes',[tbx{1}.name '_mods']);
                    if exist(modDir,'dir')
                        modDir = reshape(strsplit(genpath(modDir),pathsep),[],1);
                        p = [modDir; setdiff(p,modDir)];
                    end
                end
            end
            
            % clean
            p(cellfun(@isempty, p)) = [];
        end

    end
end

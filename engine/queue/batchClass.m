
classdef batchClass < queueClass
    properties % (Access = private)
        pool
        taskFlags % 0 - in queue; job.ID - submitted; -inf - finished; -1 error
        updateTime = 10 % s to wait for the scheduler to update job states
        waitBeforeNext = 60 % s to wait when no task or worker is available
    end

    properties (Depend)
        numWorkers
    end

    methods
        function this = batchClass(rap)
            this = this@queueClass(rap);

            if isOctave()
                poolProfile = strsplit(rap.directoryconventions.poolprofile,':');
                if ispc()
                    if numel(poolProfile{1}) == 1 % pool profile is a full path
                        poolProfile{1} = strjoin(poolProfile(1:2),':');
                        poolProfile(2) = [];
                    end
                    this.pool = poolClass('local_PS');
                elseif isunix()
                    this.pool = poolClass('slurm');
                elseif ismac()
                    logging.error('NYI');
                end
                if numel(poolProfile) > 1, pool.submitArguments = poolProfile{2}; end
            else
                logging.error('NYI');
            end

            this.pool.numWorkers = rap.options.parallelresources.numberofworkers;
            this.pool.reqMemory = rap.options.parallelresources.memory;
            this.pool.reqWalltime = rap.options.parallelresources.walltime;
            this.pool.jobStorageLocation = this.queueFolder;
        end

        function val = get.numWorkers(this)
            val = this.pool.numWorkers;
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
                    nAvailableWorkers = this.pool.numWorkers - this.pool.getJobState('running');
                else
                    logging.error('NYI');
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
                    else
                        j = batch(this.pool,@runModule,1,{this.rap task.indTask 'doit' task.indices 'reproacache' reproacache 'reproaworker' '$thisworker'},...
                              'name',task.name,...
                              'AutoAttachFiles', false, ...
                              'AutoAddClientPath', false, ...
                              'AdditionalPaths', this.getAdditionalPaths(),...
                              'CaptureDiary', true);
                    end
                    this.reportTasks('submitted',i);
                    this.taskFlags(i) = j.id;
                end

                % Wait before checking
                pause(this.updateTime);
                if toWait, pause(this.waitBeforeNext-this.updateTime); end

                % Monitor jobs
                if isOctave()
                    jobState = cellfun(@(j) {j.id j.state}, this.pool.jobs(cellfun(@(j) ismember(j.id,this.taskFlags), this.pool.jobs)), 'UniformOutput',false);
                    jobState = cat(1,jobState{:});
                else
                    logging.error('NYI');
                end

                if ~any(cellfun(@(s) any(strcmp(s,{'finished' 'error'})), jobState(:,2)))
                    logging.info('All tasks are running');
                    continue;
                end

                % Monitor reproa tasks
                % done
                %   - submitted % isDone
                % failed
                %   - submitted & error
                %   - submitted & ~isDone & finished
                doneTask = arrayfun(@(t) this.taskFlags(t)>0 && this.taskQueue{t}.isDone(), 1:numel(this.taskFlags));
                failedTask = arrayfun(@(t) this.taskFlags(t)>0 && ...
                                           (strcmp(jobState{[jobState{:,1}] == this.taskFlags(t),2},'error') | ...
                                            (strcmp(jobState{[jobState{:,1}] == this.taskFlags(t),2},'finished') & ~this.taskQueue{t}.isDone())), ...
                                      1:numel(this.taskFlags));

                % Report reproa tasks
                this.taskFlags(doneTask) = -Inf;
                this.reportTasks('finished',find(doneTask));
                if any(failedTask)
                    this.reportTasks('failed',find(failedTask));
                    break;
                end
            end
            if ~strcmp(this.status,'error')
                this.pStatus = this.STATUS('finished');
                logging.info('Task queue is finished!');
            end
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
        end

    end
end

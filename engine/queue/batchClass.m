classdef batchClass < queueClass
    properties (Access = private)
        pool
        taskFlags % 0 - in queue; 1 - submitted; 2 - reported
    end

    properties (Depend)
        numWorkers
    end

    methods
        function this = batchClass(rap)
            this = this@queueClass(rap);

            if isOctave()
                if ispc()
                    this.pool = poolClass('+pooldef\+local_PS\local_PS.json');
                elseif isunix()
                    logging.error('NYI');
                elseif ismac()
                    logging.error('NYI');
                end
            else
                logging.error('NYI');
            end

            this.pool.numWorkers = rap.options.parallelresources.numberofworkers;
            this.pool.jobStorageLocation = this.queueFolder;
        end

        function val = get.numWorkers(this)
            this.pool.numWorkers;
        end

        % Run all tasks on the queue using batch
        function this = runall(this)
            this.taskFlags = zeros(1,numel(this.taskQueue));

            global reproacache

            while ~isempty(this.taskQueue)
                this.pStatus = this.STATUS('running');

                % Ready and still in queue
                nextTaskIndices = find(cellfun(@(t) t.isNext(), this.taskQueue) & ~this.taskFlags);

                if isempty(nextTaskIndices)
                    logging.info('There is no available task -> wait for 60s');
                    pause(60);
                    continue;
                end

                if isOctave()
                    nAvailableWorkers = this.pool.numWorkers - this.pool.getJobState('running');
                else
                    logging.error('NYI');
                end
                if nAvailableWorkers == 0
                    logging.info('There is no available worker -> wait for 60s');
                    pause(60);
                    continue;
                end

                % Submit tasks
                for i = nextTaskIndices(1:min([numel(nextTaskIndices) nAvailableWorkers]))
                    task = this.taskQueue{i};
                    if isOctave()
                        batch(this.pool,@runModule,1,{this.rap task.indTask 'doit' task.indices 'reproacache' struct(reproacache) 'reproaworker' '$thisworker'},...
                              'name',task.name,...
                              'additionalPaths',this.getAdditionalPaths());
                    else
                        batch(this.pool,@runModule,1,{this.rap task.indTask 'doit' task.indices 'reproacache' reproacache 'reproaworker' '$thisworker'},...
                              'name',task.name,...
                              'AutoAttachFiles', false, ...
                              'AutoAddClientPath', false, ...
                              'AdditionalPaths', this.getAdditionalPaths(),...
                              'CaptureDiary', true);
                    end
                    this.taskFlags(i) = 1;
                end

                % Monitor tasks
                if isOctave()
                    jobState = cellfun(@(j) {strrep(j.tasks{1}.name,'Task1_','') j.state}, this.pool.jobs, 'UniformOutput',false);
                    jobState = cat(1,jobState{:});
                else
                    logging.error('NYI');
                end
                % - consider only those still in the taskSubmitted
                [~, indJob, indTask] = intersect(jobState(:,1),cellfun(@(t) t.name, ...
                                                 this.taskQueue(this.taskFlags==1), 'UniformOutput',false));
                jobState = jobState(indJob,:);

                if ~any(cellfun(@(s) any(strcmp(s,{'finished' 'error'})), jobState(:,2)))
                    logging.info('All tasks are running');
                    continue;
                end

                % Process tasks
                doneTaskIndices = find(cellfun(@(t) t.isDone(), this.taskQueue) & (this.taskFlags==1));
                this.reportTasks('finished',doneTaskIndices);
                if ~isequal(find(this.taskFlags==1),doneTaskIndices)
                    this.reportTasks('failed',setdiff(find(this.taskFlags==1),doneTaskIndices));
                    break;
                end
                if ~isempty(doneTaskIndices)
                    this.taskQueue(doneTaskIndices) = [];
                    this.taskFlags(doneTaskIndices) = 2;
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

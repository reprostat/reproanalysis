classdef queueClass < statusClass
    properties
        rap
        taskQueue = {}
    end

    properties (Access = protected, Constant = true)
        STATUS = containers.Map(...
            {'error' 'closed' 'empty' 'pending' 'running' 'finished'},...
            [-1 0 1 2 3 4] ...
            );
    end

    properties (Access = protected)
        queueFolder
        currentQueueInd = 0
    end

    methods
        function this = queueClass(rap)
            if ~isa(this,'localsingleClass')
                global reproacache
                if ~isa(reproacache,'cacheClass'), logging.error('Cannot find reproacache'); end
                global reproaworker
                if ~isa(reproaworker,'workerClass'), logging.error('Cannot find reproaworker'); end

                reproa = reproacache('reproa');

                if isOctave, strnow = char(datetime(clock,'yyyymmddHHMMSS'));
                else, strnow = char(datetime(clock,'Format','yyyyMMddHHmmss'));
                end
                this.queueFolder = fullfile(reproa.configdir,['queue_' strnow]);
                dirMake(this.queueFolder);
                reproaworker.logFile = spm_file(reproaworker.logFile,'path',this.queueFolder);
            end

            this.rap = rap;
            this.pStatus = this.STATUS('pending');
        end

        function close(this)
            logger.info('Queue is closed!');
            this.isOpen = false;
        end

        function set.taskQueue(this,j)
            this.taskQueue = j;
            if this.pStatus > this.STATUS('closed') && this.pStatus < this.STATUS('running'), this.pStatus = this.STATUS('empty')+~isempty(this.taskQueue); end
        end

        function save(this,fn)
            taskQueue = this.taskQueue;
            rap = this.rap;
            save(fn,'taskQueue','rap')
        end

        function resp = addTask(this,indTask,indices)
            task = reproaTaskClass(this.rap,indTask,indices);
            if ~task.isDone()
                this.currentQueueInd = this.currentQueueInd+1;
                this.taskQueue{end+1} = task;
                this.taskQueue{end}.indQueue = this.currentQueueInd;
                resp = true;
            else
                logging.info('DONE - %s', task.description);
                resp = false;
            end
        end

        function reportTasks(this,status,queueIndices)
            msg = cellfun(@(t) sprintf('%s - #%3d: %s in %s\n',upper(status),t.indQueue,t.description,t.duration), this.taskQueue(queueIndices),'UniformOutput',false);
            logging.info('%s',sprintf('%s',msg{:}));
            switch status
                case 'failed'
                    this.pStatus = this.STATUS('error');
            end
        end

    end
end

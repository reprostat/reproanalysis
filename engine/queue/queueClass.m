classdef queueClass < statusClass
    properties
        rap
        taskQueue = reproaTaskClass.empty()
    end

    properties (Access = protected, Constant = true)
        STATUS = containers.Map(...
            {'error' 'closed' 'empty' 'pending' 'running'},...
            [-1 0 1 2 3] ...
            );
    end

    methods
        function this = queueClass(rap)
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

        function addTask(this,k,indices)
            logging.error('NYI')
%            analysisroot = ;
%            moduleFile = ;
%            indices = ;
%            waitFor = ;
%
%            this.taskQueue = [this.taskQueue,...
%                reproaTaskClass(analysisroot,moduleFile,indices,waitFor)...
%                ];
        end

    end
end

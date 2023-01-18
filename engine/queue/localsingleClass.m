classdef localsingleClass < queueClass
    methods
        function this = localsingleClass(rap)
            this = this@queueClass(rap);
        end

        % Run all tasks on the queue, single threaded
        function this = runall(this)
            if ~isempty(this.taskQueue)
                this.pStatus = this.STATUS('running');
                nextTaskIndices = find(arrayfun(@(i) this.taskQueue(i).isNext(), 1:numel(this.taskQueue)));
                for i = nextTaskIndices
                    task = this.taskQueue(i);
                    this.rap = runModule(this.rap,task.indTask,'doit',task.indices);
                end
                doneTaskIndices = find(arrayfun(@(i) this.taskQueue(i).isDone(), 1:numel(this.taskQueue)));
                this.reportTasks('finished',doneTaskIndices);
                if ~isequal(nextTaskIndices,doneTaskIndices)
                    this.reportTasks('failed',setdiff(nextTaskIndices,doneTaskIndices));
                end
                if ~isempty(doneTaskIndices), this.taskQueue(doneTaskIndices) = []; end
            else
                this.pStatus = this.STATUS('finished');
                logging.info('Task queue is finished!');
            end
        end
    end
end

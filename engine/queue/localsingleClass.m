classdef localsingleClass < queueClass
    methods
        function this = localsingleClass(rap)
            this = this@queueClass(rap);
        end

        % Run all tasks on the queue, single threaded
        function this = runall(this,toDo)
            if ~isempty(this.taskQueue)
                this.pStatus = this.STATUS('running');
                nextTaskIndices = find([this.taskQueue.isNext()]);
                for taskInd = nextTaskIndices
                    this.rap = this.taskQueue(taskInd).process(this.rap);
                end
                doneTaskIndices = find([this.taskQueue.isDone()]);
                this.reportTasks('finished',doneTaskIndices);
                if ~isequal(nextTaskIndices,doneTaskIndices)
                    this.reportTasks('failed',setdiff(nextTaskIndices,doneTaskIndices));
                end
                this.taskQueue(doneTaskIndices) = [];
            else
                this.pStatus = this.STATUS('finished');
                logging.info('Task queue is finished!');
            end
        end
    end
end


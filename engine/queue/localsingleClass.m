classdef localsingleClass < queueClass
    methods
        function this = localsingleClass(rap)
            this = this@queueClass(rap);
        end

        % Run all tasks on the queue, single threaded
        function this = runall(this,toDo)
            while ~isempty(this.taskQueue)
                task = this.taskQueue(1);
                this.rap = task.process(this.rap,toDo);
            end
        end
    end
end


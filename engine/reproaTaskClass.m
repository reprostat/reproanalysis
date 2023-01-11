classdef reproaTaskClass
    properties
        name
        doneflag
    end

    properties (Access=private)
        indTask
        indices
        taskRoot
        waitFor
    end

    properties (Access=private, Constant=true)
        DONEFLAG = 'done'
    end

    methods
        function this = reproaTaskClass(rap,indTask,indices)
            if nargin
                this.indTask = indTask;
                this.indices = indices;

                rap = setCurrenttask(rap,'task',this.indTask);

                % get dependency
                waitFor = {};
                for s = rap.tasklist.currenttask.inputstreams
                    deps = getDependencyByDomain(rap,s.domain,rap.tasklist.currenttask.domain,this.indices);
                    for d = 1:size(deps,1)
                        waitFor{end+1} = fullfile(getPathByDomain(rap,s.domain,deps(d,:)),this.DONEFLAG);
                    end
                end

                this.name = rap.tasklist.currenttask.name;
                this.taskRoot = getPathByDomain(rap,rap.tasklist.currenttask.domain,this.indices);
                this.doneflag = fullfile(this.taskRoot,this.DONEFLAG);
                this.waitFor = waitFor; % list of doneflags
            end
        end

        function resp = isReady(this)
            isDone = cellfun(@(df) this.doneflagExists(df), this.waitFor);
            this.waitFor(isDone) = [];

            resp = isempty(this.waitFor);
        end

        function rap = process(this,rap,toDo)
            rap = runModule(rap,this.indTask,'doit',this.indices);
            fclose(fopen(this.doneflag,'w'));
        end

        function resp = isDone(this)
            resp = doneflagExists(this)
        end

    end

    methods (Access=private)
        function resp = doneflagExists(this,doneflag)
            if nargin < 2, doneflag = this.doneflag; end
            if strcmp(this.taskRoot(1:4),'s3://')
    %            global reproaworker
    %            attr = sdb_get_attributes(reproaworker.doneflagtablename,doneflag);
    %            resp = ~isempty(attr);
        else
                resp = logical(exist(doneflag,'file'));
            end
        end
    end

    methods  (Static = true)
        function this = empty()
            this = reproaTaskClass();
            this = this(false);
        end
    end
end

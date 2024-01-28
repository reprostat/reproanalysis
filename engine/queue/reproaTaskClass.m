classdef reproaTaskClass
    properties
        indQueue
        name
        description

        indTask
        indices
    end

    properties (Access=private)
        taskRoot
        waitFor

        doneflag
    end

    methods
        function this = reproaTaskClass(rap,indTask,indices)
            global reproacache

            this.indTask = indTask;
            this.indices = indices;

            rap = setCurrenttask(rap,'task',this.indTask);

            % get dependency
            waitFor = {};
            for s = rap.tasklist.currenttask.inputstreams
                if ~isfield(s,'path') || isempty(s.path) % skip for remote (already done)
                    deps = getDependencyByDomain(rap,s.taskdomain,rap.tasklist.currenttask.domain,this.indices);
                    for d = 1:size(deps,1)
                        waitFor{end+1} = fullfile(getPathByDomain(rap,s.taskdomain,deps(d,:),'task',s.taskindex),reproacache('doneflag'));
                    end
                end
            end

            this.name = rap.tasklist.currenttask.name;
            this.description = getTaskDescription(rap,indices);
            this.taskRoot = getPathByDomain(rap,rap.tasklist.currenttask.domain,this.indices);
            this.doneflag = fullfile(this.taskRoot,reproacache('doneflag'));
            this.waitFor = waitFor; % list of doneflags
        end

        function resp = isNext(this)
            isDone = cellfun(@(df) this.doneflagExists(df), this.waitFor);
            this.waitFor(isDone) = [];

            resp = isempty(this.waitFor);
        end

        function resp = isDone(this)
            resp = this.doneflagExists();
        end

        function resp = duration(this)
            resp = "";
            if this.isDone()
                fid = fopen(this.doneflag,'r');
                resp = fgetl(fid);
                fclose(fid);
            end
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

end

function rap = buildWorkflow(rap,varargin)

    argParse = inputParser;
    argParse.addParameter('saveProvenance',true,@(x) islogical(x) || isnumeric(x));
    argParse.addParameter('isProbe',false,@(x) islogical(x) || isnumeric(x));
    argParse.parse(varargin{:});

    if argParse.Results.saveProvenance
        provfn = fullfile(rap.acqdetails.root,rap.directoryconventions.analysisid,'rap_prov.dot');
        pfid = fopen(provfn,'w');
        fprintf(pfid,'digraph {\n\t');
        dotR = {};

        cmapfn = fullfile(rap.acqdetails.root,rap.directoryconventions.analysisid,'rap_cmap.txt');
        cfid = fopen(cmapfn,'w');
    end

    for indTask = 1:numel(rap.tasklist.main)
        taskName = rap.tasklist.main(indTask).name;
        taskIndex = rap.tasklist.main(indTask).index;

        taskToCheck = true(1,indTask-1);

        % identify relevant tasks based on branchID
        if ~isempty(rap.tasklist.main(indTask).branchid)
            taskToCheck = taskToCheck & cellfun(@(b) startsWith(rap.tasklist.main(indTask).branchid,b), {rap.tasklist.main(1:indTask-1).branchid});
        end

        for indInput = 1:numel(rap.tasklist.main(indTask).inputstreams)
            inputstream = rap.tasklist.main(indTask).inputstreams(indInput);
            hasSource = false;
            indSource = [];

            % if fully specified
            if any(inputstream.name == '.')
                tmp = strsplit(inputstream.name,'[_|.]','delimitertype','regularexpression');
                [sourceTaskName sourceTaskIndex inputstream.name] = deal(tmp{:}); sourceTaskIndex = sscanf(sourceTaskIndex,'%05d');
                taskToCheck = taskToCheck & strcmp({rap.tasklist.main(1:indTask-1).name},sourceTaskName) & ({rap.tasklist.main(1:indTask-1).index}==sourceTaskIndex);
            end

            if any(taskToCheck)
                indSource = find(arrayfun(@(i) taskToCheck(i) & ~isempty(rap.tasklist.main(i).outputstreams) || any(strcmp({rap.tasklist.main(i).outputstreams.name},inputstream.name)), 1:indTask-1),1,'last');
            end

            if ~isempty(indSource)
                sourceName = rap.tasklist.main(indSource).name;
                sourceIndex = rap.tasklist.main(indSource).index;
                logging.info('Task %s input %s comes from %s which is %d step(s) prior',taskName,inputstream.name,sourceName,indTask-indSource);
                % write provenance
                if argParse.Results.saveProvenance
                    fprintf(pfid,'"R%s_%05d" -> "R%s_%05d" [ label="%s" ];',sourceName,sourceIndex,taskName,taskIndex,inputstream.name);
                    dotR(end+1) = cellstr(sprintf('%s_%05d',sourceName,sourceIndex));
                    dotR(end+1) = cellstr(sprintf('%s_%05d',taskName,taskIndex));
                    fprintf(cfid,'%s_%05d\t%s\t%s_%05d\n',sourceName,sourceIndex,inputstream.name,taskName,taskIndex);
                end

                % Update inputstream
                hasSource = true;
                indOutput = strcmp({rap.tasklist.main(indSource).outputstreams.name},inputstream.name);
                rap.tasklist.main(indTask).inputstreams(indInput).taskindex = indSource;
                rap.tasklist.main(indTask).inputstreams(indInput).domain = rap.tasklist.main(indSource).outputstreams(indOutput).domain;
                rap.tasklist.main(indTask).inputstreams(indInput).modality = rap.tasklist.main(indSource).header.modality;

                % Update outputstream
                streamInd = strcmp({rap.tasklist.main(indSource).outputstreams.name},inputstream.name);
                if ~isfield(rap.tasklist.main(indSource).outputstreams(streamInd),'taskindex') % first update
                    rap.tasklist.main(indSource).outputstreams(streamInd).taskindex = indTask;
                else
                    rap.tasklist.main(indSource).outputstreams(streamInd).taskindex(end+1) = indTask;
                end
            elseif ~isempty(rap.acqdetails.input.remotepipeline(1).path) % Check remote
                logging.error('NYI')
%                rap.tasklist.main(indTask).inputstreams(indInput).name = ;
%                rap.tasklist.main(indTask).inputstreams(indInput).taskindex = -1;
%                rap.tasklist.main(indTask).inputstreams(indInput).domain =
%                rap.tasklist.main(indTask).inputstreams(indInput).modality =
%                rap.tasklist.main(indTask).inputstreams(indInput).host =
%                rap.tasklist.main(indTask).inputstreams(indInput).rapPath =
%                rap.tasklist.main(indTask).inputstreams(indInput).allowCache =
            end

            if ~hasSource && ~argParse.Results.isProbe
                logging.error('Task %s requires %s which is not an output of any task in the same branch. You might need to add it via the addInitialStream or from a remote pipeline.',taskName,inputstream.name);
            end
        end
        % update domain and modality of generic modules based on the main input, which is expected to be the last inputstream
        if strcmp(rap.tasklist.main(indTask).header.domain, '?')
            rap.tasklist.main(indTask).header.domain = rap.tasklist.main(indTask).inputstreams(end).domain;
            rap.tasklist.main(indTask).header.modality = rap.tasklist.main(indTask).inputstreams(end).modality;
        end
    end

    if argParse.Results.saveProvenance
        dotR = unique(dotR,'stable');
        for r = 1:numel(dotR)
            fprintf(pfid,'\t"R%s" [ label="%s", shape = ellipse, color = blue ];\n',dotR{r},dotR{r});
        end
        fprintf(pfid,'}');
        fclose(pfid);
        % - create provenance image (only in unix, requires dot)
        if ~unix('which dot')
            unix(sprintf('dot %s -Grankdir=TB -Tpng -o %s',provfn,strrep(provfn,'dot','png')));
        end

        fclose(cfid);
    end
end

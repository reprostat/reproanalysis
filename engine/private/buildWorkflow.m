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

        inputToOmit = []; % non-existing non-essential streams
        for indInput = 1:numel(rap.tasklist.main(indTask).inputstreams)
            clear sourceTaskName
            isRemote = false;
            inputstream = rap.tasklist.main(indTask).inputstreams(indInput);
            if iscell(inputstream.name), inputstream.name = inputstream.name{1}; end % ingore original name after renaming
            indSource = [];
            sourceToCheck = taskToCheck;

            % if fully specified
            if any(inputstream.name == '.') && ~isempty(regexp(inputstream.name,'[0-9]{5}(?=\.)'))
                tmp = regexp(inputstream.name,'^.*(?=_[0-9])|[0-9]{5}|(?<=\.).*','match');
                [sourceTaskName sourceTaskIndex inputstream.name] = deal(tmp{:}); sourceTaskIndex = sscanf(sourceTaskIndex,'%05d');
                sourceToCheck = sourceToCheck & strcmp({rap.tasklist.main(1:indTask-1).name},sourceTaskName) & ([rap.tasklist.main(1:indTask-1).index]==sourceTaskIndex);
            end
            % if content
            if any(inputstream.name == '.'), inputstream.name = regexp(inputstream.name,'^.*(?=\.)','match','once'); end

            if any(sourceToCheck)
                indSource = find(arrayfun(@(i) sourceToCheck(i) && ~isempty(rap.tasklist.main(i).outputstreams) && any(arrayfun(@(s) any(strcmp(s.name,inputstream.name)),rap.tasklist.main(i).outputstreams)), 1:indTask-1),1,'last');
            end

            if isempty(indSource) && ~isempty(rap.acqdetails.input.remoteworkflow(1).path) % Check remote
                global reproacache

                for r = 1:numel(rap.acqdetails.input.remoteworkflow)
                    remote = reproacache(sprintf('input.remote%d',r));
                    sourceToCheck = true(1,remote.maxtask);
                    % branch-specific check - make sure that the local workflow has branch IDs corresponding to that of the remote workflow.
                    if ~isempty(rap.tasklist.main(indTask).branchid)
                        sourceToCheck = sourceToCheck & cellfun(@(b) startsWith(rap.tasklist.main(indTask).branchid,b), {remote.rap.tasklist.main(1:remote.maxtask).branchid});
                    end
                    % fully specified
                    if exist('sourceTaskName','var')
                        sourceToCheck = sourceToCheck & strcmp({remote.rap.tasklist.main(1:remote.maxtask).name},sourceTaskName) &...
                                                        ([remote.rap.tasklist.main(1:remote.maxtask).index]==sourceTaskIndex);
                    end

                    if any(sourceToCheck)
                        indSource = find(arrayfun(@(i) sourceToCheck(i) && ~isempty(remote.rap.tasklist.main(i).outputstreams) && any(arrayfun(@(s) any(strcmp(s.name,inputstream.name)),remote.rap.tasklist.main(i).outputstreams)), 1:remote.maxtask),1,'last');
                    end

                    if ~isempty(indSource)
                        rap.tasklist.main(indTask).inputstreams(indInput).host = remote.host;
                        rap.tasklist.main(indTask).inputstreams(indInput).path = remote.path;
                        rap.tasklist.main(indTask).inputstreams(indInput).allowCache = remote.allowcache;
                        isRemote = true; % indicate remote
                        break;
                    end
                end
            end

            if ~isempty(indSource)
                if ~isRemote > 0 % local
                    inputrap = rap;
                    sourceName = inputrap.tasklist.main(indSource).name;
                    logging.info('Task %s input %s comes from %s which is %d step(s) prior',taskName,inputstream.name,sourceName,indTask-indSource);
                else % remote
                    inputrap = remote.rap;
                    sourceName = inputrap.tasklist.main(indSource).name;
                    remoteName = sprintf('remote%d-%s',r,inputrap.directoryconventions.analysisid);
                    logging.info('Task %s input %s comes from %s:%s',taskName,inputstream.name,remoteName,sourceName);
                end
                sourceIndex = inputrap.tasklist.main(indSource).index;

                % write provenance
                if argParse.Results.saveProvenance
                    if isRemote
                        fprintf(pfid,'"R%s" -> "R%s_%05d" [ label="connect" ];',remoteName,sourceName,sourceIndex);
                        dotR(end+1) = cellstr(remoteName);
                        fprintf(cfid,'%s\tconnect\t%s_%05d\n',remoteName,sourceName,sourceIndex);
                    end
                    fprintf(pfid,'"R%s_%05d" -> "R%s_%05d" [ label="%s" ];',sourceName,sourceIndex,taskName,taskIndex,inputstream.name);
                    dotR(end+1) = cellstr(sprintf('%s_%05d',sourceName,sourceIndex));
                    dotR(end+1) = cellstr(sprintf('%s_%05d',taskName,taskIndex));
                    fprintf(cfid,'%s_%05d\t%s\t%s_%05d\n',sourceName,sourceIndex,inputstream.name,taskName,taskIndex);
                end

                % Update inputstream
                selectOutput = arrayfun(@(s) any(strcmp(s.name,inputstream.name)), inputrap.tasklist.main(indSource).outputstreams);
                rap.tasklist.main(indTask).inputstreams(indInput).taskindex = indSource;
                rap.tasklist.main(indTask).inputstreams(indInput).taskdomain = inputrap.tasklist.main(indSource).header.domain;
                rap.tasklist.main(indTask).inputstreams(indInput).streamdomain = inputrap.tasklist.main(indSource).outputstreams(selectOutput).domain;
                rap.tasklist.main(indTask).inputstreams(indInput).modality = inputrap.tasklist.main(indSource).header.modality;

                % Update local outputstream
                if ~isRemote
                    if ~isfield(inputrap.tasklist.main(indSource).outputstreams(selectOutput),'taskindex') % first update
                        rap.tasklist.main(indSource).outputstreams(selectOutput).taskindex = indTask;
                    else
                        if ~any(inputrap.tasklist.main(indSource).outputstreams(selectOutput).taskindex==indTask)
                            rap.tasklist.main(indSource).outputstreams(selectOutput).taskindex(end+1) = indTask;
                        end
                    end
                end
            elseif ~inputstream.isessential
                inputToOmit(end+1) = indInput;
            else ~argParse.Results.isProbe
                logging.error('Task %s requires %s which is not an output of any task in the same branch. You might need to add it via the addFile or from a remote workflow.',taskName,inputstream.name);
            end
        end

        if ~argParse.Results.isProbe, rap.tasklist.main(indTask).inputstreams(inputToOmit) = []; end

        % update domain and modality of generic modules based on the main input, which is expected to be the last inputstream
        if strcmp(rap.tasklist.main(indTask).header.domain, '?') && ~isempty(rap.tasklist.main(indTask).inputstreams)
            rap.tasklist.main(indTask).header.domain = rap.tasklist.main(indTask).inputstreams(end).streamdomain;
            rap.tasklist.main(indTask).header.modality = rap.tasklist.main(indTask).inputstreams(end).modality;
            % update outputstreams' domain
            for indOutput = find(strcmp({rap.tasklist.main(indTask).outputstreams.domain},'?'))
                rap.tasklist.main(indTask).outputstreams(indOutput).domain = rap.tasklist.main(indTask).header.domain;
            end
        end
    end

    % Update domain and modality of generic modules (with no input, see line 92) backwards based on the main output, which is expected to be the first (valid) outputstream
    for indTask = numel(rap.tasklist.main):-1:1
        if strcmp(rap.tasklist.main(indTask).header.domain, '?')
            outputTaskInds = [rap.tasklist.main(indTask).outputstreams.taskindex];
            outputTask = rap.tasklist.main(outputTaskInds(1));
            rap.tasklist.main(indTask).header.domain = outputTask.header.domain;
            rap.tasklist.main(indTask).header.modality = outputTask.header.modality;
            % update outputstreams' domain
            for indOutput = find(strcmp({rap.tasklist.main(indTask).outputstreams.domain},'?'))
                rap.tasklist.main(indTask).outputstreams(indOutput).domain = rap.tasklist.main(indTask).header.domain;
            end
        end
    end

    if argParse.Results.saveProvenance
        dotR = unique(dotR,'stable');
        for r = 1:numel(dotR)
            fprintf(pfid,'\t"R%s" [ label="%s", shape = ellipse, color = blue ];\n',dotR{r},dotR{r});
        end
        fprintf(pfid,'}');
        fclose(pfid);
        % - create provenance image (requires Graphviz/dot)
        if isOctave()
            hasDot = ~system('which dot');
        else
            hasDot = ~isempty(which('dot'));
        end
        if hasDot
            system(sprintf('dot %s -Grankdir=TB -Tpng -o %s',provfn,strrep(provfn,'dot','png')));
        else
            logging.warning('Drawing the provenance graph requires Graphviz added to the system path.');
        end

        fclose(cfid);
    end
end

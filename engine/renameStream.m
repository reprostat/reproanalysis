% To rename stream: renameStream(rap,taskName,'input'|'output',originalStream,newStream[:attribute-value])
% To remove stream: renameStream(rap,taskName,'input'|'output',originalStream,'')
% To add stream:    renameStream(rap,taskName,'input'|'output','append',newStream[:attribute-value])

function rap = renameStream(rap,taskName,streamType,originalStream,newStream)

    % locate task
    taskName = strsplit(taskName,'_');
    index = str2double(taskName{end});
    taskName = strjoin(taskName(1:end-1),'_');
    selectTask = strcmp({rap.tasklist.main.name},taskName) & ([rap.tasklist.main.index] == index);

    if strcmp(originalStream,'append')
        selectStream = numel(rap.tasklist.main(selectTask).([streamType 'streams']))+1;
        newStreamSpec = struct(...
            'name','',...
            'domain',rap.tasklist.main(selectTask).header.domain,...
            'isessential',1,...
            'isrenameable',0,...
            'tobemodified',1,...
            'taskindex',[]...
            );
    else
        selectStream = strcmp({rap.tasklist.main(selectTask).([streamType 'streams']).name},originalStream);
        if ~any(selectStream), logging.error('%s stream %s of task %s not found',streamType,originalStream,rap.tasklist.main(selectTask).name); end
        if ~strcmp(regexp(char(newStream),'(?<=\.).*','match','once'),originalStream) && ... % do not check if it only fully specification
            ~rap.tasklist.main(selectTask).([streamType 'streams'])(selectStream).isrenameable && ...
            rap.tasklist.main(selectTask).([streamType 'streams'])(selectStream).isessential
                logging.error('%s stream %s of task %s is not renameable and cannot be missed',streamType,originalStream,rap.tasklist.main(selectTask).name);
        end
        newStreamSpec = rap.tasklist.main(selectTask).([streamType 'streams'])(selectStream);
    end

    if ~isempty(newStream)
        newStream = strsplit(newStream,':');
        if strcmp(originalStream,'append'), newStreamSpec.name = newStream{1};
        else, newStreamSpec.name = [newStream(1) cellstr(newStreamSpec.name)]; % keep the original name for reference (within the module)
        end
        for a = newStream(2:end) % process attributes ('attribute-value')
            spec = strsplit(a{1},'-');
            if strcmp(spec{1},'domain')
                newStreamSpec.(spec{1}) = spec{2};
            else % flag
                newStreamSpec.(spec{1}) = str2double(spec{2});
            end
        end
        if ~isempty(rap.tasklist.main(selectTask).([streamType 'streams']))
            newStreamSpec = rmfield(newStreamSpec,setdiff(fieldnames(newStreamSpec),fieldnames(rap.tasklist.main(selectTask).([streamType 'streams'])(1))));
        end
        rap.tasklist.main(selectTask).([streamType 'streams'])(selectStream) = newStreamSpec;
    else
        rap.tasklist.main(selectTask).([streamType 'streams']) = rap.tasklist.main(selectTask).([streamType 'streams'])(~selectStream);
    end

end

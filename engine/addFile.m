function rap = addFile(rap,domain,indices,streamName,files)

    indices = getIndicesByName(rap,domain,indices);

    % Check if a reproa_addfile task at the appropriate domain already exists
    indTask = 0;
    for i=1:numel(rap.tasklist.main)
        if strcmp(rap.tasklist.main(i).name,'reproa_addfile') ...
                && strcmp(rap.tasklist.main(i).header.domain,domain)
            indTask = i;
            break
        end
    end

    % Add task if not exists
    if ~indTask
        indTask = 1;
        rap.tasklist.main = [readModule('reproa_addfile.xml') rap.tasklist.main];
        rap.tasklist.main(1).index = sum(strcmp({rap.tasklist.main.name},'reproa_addfile'));
        rap.tasklist.main(1).header.domain = domain;

        % - defaults
        rap.tasklist.main(1).branchid = 'a';
        rap.tasklist.main(1).extraparameters.rap.directoryconventions.analysisidsuffix = '';
        rap.tasklist.main(1).extraparameters.rap.acqdetails.selectedruns = '*';

        rap.tasksettings.reproa_addfile(rap.tasklist.main(1).index) = rap.tasklist.main(1).settings;
        rap.tasksettings.reproa_addfile(rap.tasklist.main(1).index).data = ...
            rap.tasksettings.reproa_addfile(rap.tasklist.main(1).index).data(false);
    end

    % Ensure stream
    currrap = setCurrenttask(rap,'task',indTask);
    if ~hasStream(currrap,streamName)
        rap = renameStream(rap,getTaskDescription(currrap,[],'taskname'),'output','append',streamName);
    end

    % Add files
    if ~iscell(files), files = cellstr(files); end
    for i = 1:numel(files)
        if exist(files{i},'file'), files{i} = ['file://' files{i}]; end
    end
    rap.tasksettings.reproa_addfile(currrap.tasklist.currenttask.index).data(end+1) = ...
        struct('indices',indices, ...
               'streamname',streamName, ...
               'files',{files});
end

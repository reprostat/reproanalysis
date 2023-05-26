% Put file(s) into stream
%  function putFileByStream(rap,domain,indices,streamName,fileNames)
%  e.g.,
%   putFileByStream(rap,'subject',[1],'structural',fns)
%   putFileByStream(rap,'fmrirun',[1,1],'fmri',fns)
%
% File names may be provided in a cell array or as a character matrix.
% File names may either be specified using a relative to task path or absolute path. If the latter, the path is converted to relative.

function  putFileByStream(rap,domain,indices,streamName,fileNames)

    % locate stream
    selectStream = arrayfun(@(s) any(strcmp(s.name,streamName)), rap.tasklist.currenttask.outputstreams);
    if ~any(selectStream), logging.error('Task %s has not output %s',rap.tasklist.currenttask.name,streamName); end
    stream = rap.tasklist.currenttask.outputstreams(selectStream);
    streamName = stream.name; if iscell(streamName), streamName = streamName{1}; end

    taskPath = getPathByDomain(rap,domain,indices);

    % make sure the path is canonical
    taskPath = readLink(taskPath);

    streamDescriptor = fullfile(taskPath,sprintf('stream_%s_outputfrom_%s.txt',streamName,rap.tasklist.currenttask.name));

    % Unify format as a struct with description - cells
    if ischar(fileNames), fileNames = cellstr(fileNames); end
    if ~isstruct(fileNames)
        fn = fileNames; fileNames = struct(); fileNames.files = fn;
    else
        for f = fieldnames(fileNames)'
            if ischar(fileNames.(f{1})), fileNames.(f{1}) = cellstr(fileNames.(f{1})); end
        end
    end

    % Trim absolute path if it has been provided
    hashFiles = {};
    for f = fieldnames(fileNames)'
        for i = 1:numel(fileNames.(f{1}))
            if isAbsolutePath(fileNames.(f{1}){i})
                fileNames.(f{1}){i} = readLink(fileNames.(f{1}){i}); % make sure that the path is canonical
                if startsWith(fileNames.(f{1}){i},taskPath)
                    fileNames.(f{1}){i} = strrep(fileNames.(f{1}){i},[taskPath filesep],'');
                else
                    logging.error('File %s does not seems to be in the task folder %s',fileNames.(f{1}){i},taskPath);
                end
            end
        end
        hashFiles = [hashFiles reshape(fileNames.(f{1}),1,[])];
    end

    % Calculate hash
    hashStream = getHashByFiles(hashFiles,'localroot',taskPath);

    % Write stream streamDescriptor
    jsonwrite(streamDescriptor,struct('hash',hashStream,'content',fileNames));

    % And propgate to remote filesystem
    switch rap.directoryconventions.remotefilesystem
        case 's3'
            logging.error('NYI');
    end

    logsafe_path = strrep(streamDescriptor, '\', '\\');
    logging.info('\toutput stream %s %s written with %d file(s)',streamName,logsafe_path,numel(hashFiles));
end

% Put file(s) into stream
%  function putFileByStream(rap,domain,indices,streamName,files)
%  e.g.,
%   putFileByStream(rap,'subject',[1],'structural',fns)
%   putFileByStream(rap,'fmrirun',[1,1],'fmri',fns)
%
% File names may be provided in a cell array or as a character matrix.
% File names may either be specified using a relative to task path or absolute path. If the latter, the path is converted to relative.

function  putFileByStream(rap,domain,indices,streamName,files)

    % locate stream
    selectStream = arrayfun(@(s) any(strcmp(s.name,streamName)), rap.tasklist.currenttask.outputstreams);
    if ~any(selectStream), logging.error('Task %s has not output %s',rap.tasklist.currenttask.name,streamName); end
    stream = rap.tasklist.currenttask.outputstreams(selectStream);
    streamName = stream.name; if iscell(streamName), streamName = streamName{1}; end

    taskPath = getPathByDomain(rap,domain,indices);

    streamDescriptor = fullfile(taskPath,sprintf('stream_%s_outputfrom_%s.txt',streamName,rap.tasklist.currenttask.name));

    % Unify format as a struct with description as fieldnames and file(s) as cellstring values
    if ischar(files), files = cellstr(files); end
    if ~isstruct(files)
        fn = files; files = struct(); files.files = fn;
    else
        for f = fieldnames(files)'
            if ischar(files.(f{1})), files.(f{1}) = cellstr(files.(f{1})); end
        end
    end

    % Trim absolute path if it has been provided and add hashes
    allFiles = [];
    for f = fieldnames(files)'
        for i = 1:numel(files.(f{1}))
            if isAbsolutePath(files.(f{1}){i})
                if startsWith(files.(f{1}){i},taskPath)
                    files.(f{1}){i} = strrep(files.(f{1}){i},[taskPath filesep],'');
                else
                    logging.error('File %s does not seems to be in the task folder %s',files.(f{1}){i},taskPath);
                end
            end
        end
        fn = files.(f{1}); files.(f{1}) = struct();
        files.(f{1}).hash = getHashByFiles(fn,'localroot',taskPath);
        files.(f{1}).files = fn;
        allFiles = [allFiles numel(files.(f{1}).files)];
    end

    % Simplify if only single content
    if numel(fieldnames(files)) == 1, files = files.(char(fieldnames(files)));  end

    % Write stream streamDescriptor
    jsonwrite(streamDescriptor,files);

    % And propgate to remote filesystem
    switch rap.directoryconventions.remotefilesystem
        case 's3'
            logging.error('NYI');
    end

    logsafe_path = strrep(streamDescriptor, '\', '\\');
    logging.info('\toutput stream %s %s written with %d content (total %d file(s))',streamName,logsafe_path,numel(allFiles),sum(allFiles));
end

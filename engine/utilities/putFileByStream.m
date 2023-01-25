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

    % If fileNames provided as char array, reformat
    if ~iscell(fileNames), fileNames = cellstr(fileNames); end

    % Trim absolute path if it has been provided
    for f = 1:numel(fileNames)
        if isAbsolutePath(fileNames{f})
            fileNames{f} = readLink(fileNames{f}); % make sure that the path is canonical
            if strcmp(fileNames{f}(1:numel(taskPath)),taskPath)
                fileNames{f} = strrep(fileNames{f},[taskPath filesep],'');
            else
                logging.error('File %s does not seems to be in the task folder %s',fileNames{f},taskPath);
            end
        end
    end

    % Calculate hash
    hashStream = getHashByFiles(fileNames,'localroot',taskPath);

    % Write stream streamDescriptor
    fid = fopen(streamDescriptor,'w');
    fprintf(fid,'#\t%s\n',hashStream);
    cellfun(@(pth) fprintf(fid,'%s\n',pth), fileNames);
    fclose(fid);

    % And propgate to remote filesystem
    switch rap.directoryconventions.remotefilesystem
        case 's3'
            logging.error('NYI');
    end

    logsafe_path = strrep(streamDescriptor, '\', '\\');
    logging.info('\toutput stream %s %s written with %d file(s)',streamName,logsafe_path,numel(fileNames));
end

function resp = isAbsolutePath(pth)
    if isOctave
        resp = is_absolute_filename(pth);
    else
        jvFile = java.io.File(pth);
        resp = jvFile.isAbsolute();
    end
end

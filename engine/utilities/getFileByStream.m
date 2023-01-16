% Get file(s) from input- or outputstream
%  function getFileByStream(rap,domain,indices,streamName,fileNames,['input'|'output'])
%  e.g.,
%   getFileByStream(rap,'subject',[1],'structural',fns)
%   getFileByStream(rap,'fmrirun',[1,1],'fmri',fns,'output')
%
% File names may be provided in a cell array or as a character matrix.
% File names may either be specified using a relative to task path or absolute path. If the latter, the path is converted to relative.
% By default, it tries to locate the inputstream then the outputstream. If stream type is specified, then it tries to locate only the specified stream type.

function fileList = getFileByStream(rap,domain,indices,streamName,fileNames,streamType)

    if nargin == 6, streamType = {streamType};
    else, streamType = {'input' 'output'};
    end

    % If fully specified
    streamName = strsplit(streamName,'.'); streamName = streamName{end};

    taskPath = getPathByDomain(rap,domain,indices);

    % make sure the path is canonical
    taskPath = readLink(taskPath);

    % Locate streamDescriptor
    for io = streamType
        logging.info('Locating %s stream %s...',io{1},streamName);
        streamDescriptor = spm_select('FPList',taskPath,sprintf('^stream_%s_%s.*.txt$',streamName,io{1}));
        if ~isempty(streamDescriptor), break; end
    end
    if ~isempty(streamDescriptor), logging.info('\tFound at %s',streamDescriptor);
    else, logging.error('\tNo stream found');
    end

    % Check hash
    inStream = strsplit(fileRetrieve(streamDescriptor,rap.options.maximumretry,'content'),'\n');
    descHash = regexp(inStream{1},'(?<=(#\t))[0-9a-f]*','match'); descHash = descHash{1};
    fileList = inStream(2:end-1); % last is newline
    fileHash = getHashByFiles(fileList,'localroot',taskPath);
    if ~strcmp(descHash,fileHash), logging.error('%s stream %s has changed since its retrieval',io{1},streamName); end

    fileList = fullfile(taskPath,fileList);
end

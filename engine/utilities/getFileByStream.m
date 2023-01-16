% Get file(s) from input- or outputstream
%  function getFileByStream(rap,domain,indices,streamName,['streamType','input'|'output'],['isProbe',false|true])
%  e.g.,
%   getFileByStream(rap,'subject',[1],'structural')
%   getFileByStream(rap,'fmrirun',[1,1],'fmri','output')
%
% File names may be provided in a cell array or as a character matrix.
% File names may either be specified using a relative to task path or absolute path. If the latter, the path is converted to relative.
% By default, it tries to locate the inputstream then the outputstream. If stream type is specified, then it tries to locate only the specified stream type.

function fileList = getFileByStream(rap,domain,indices,streamName,varargin)

    argParse = inputParser;
    argParse.addParameter('streamType',{'input' 'output'},@(x) ischar(x) & any(strcmp({'input','output'},x)));
    argParse.addParameter('isProbe',false,@islogical);
    argParse.parse(varargin{:});

    streamType = argParse.Results.streamType; if ~iscell(streamType), streamType = {streamType}; end

    fileList = '';

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
    if ~isempty(streamDescriptor)
        logging.info('\tFound at %s',streamDescriptor);
        if argParse.Results.isProbe, fileList = 'x'; return; end
    else
        if ~argParse.Results.isProbe, logging.error('\tNo %s stream %s is found',io{1},streamName);
        else, logging.info('\tNo %s stream %s is found',io{1},streamName); return;
        end
    end

    % Check hash
    inStream = strsplit(fileRetrieve(streamDescriptor,rap.options.maximumretry,'content'),'\n');
    descHash = regexp(inStream{1},'(?<=(#\t))[0-9a-f]*','match');
    if ~isempty(descHash)
        descHash = descHash{1};
        fileList = inStream(2:end-1); % last is newline
        fileHash = getHashByFiles(fileList,'localroot',taskPath);
        if ~strcmp(descHash,fileHash), logging.error('%s stream %s has changed since its retrieval',io{1},streamName); end
        fileList = fullfile(taskPath,fileList);
    else
        if ~argParse.Results.isProbe, logging.error('\t%s stream %s is empty',io{1},streamName);
        else, logging.info('\t%s stream %s is empty',io{1},streamName); return;
        end
    end

end

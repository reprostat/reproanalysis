% Get file(s) from input- or outputstream
%  function getFileByStream(rap,domain,indices,streamName,['streamType','input'|'output'],['checkHash',false|true],['isProbe',false|true])
%  e.g.,
%   getFileByStream(rap,'subject',[1],'structural')
%   getFileByStream(rap,'fmrirun',[1,1],'fmri','output')
%   getFileByStream(rap,'subject',[1],'fmri','output')
%
% File names may be provided in a cell array or as a character matrix.
% File names may either be specified using a relative to task path or absolute path. If the latter, the path is converted to relative.
% By default, it tries to locate the inputstream then the outputstream. If stream type is specified, then it tries to locate only the specified stream type.
% It returns all stream relevant for the specified domain

function [fileList hashList streamDescriptor] = getFileByStream(rap,domain,indices,streamName,varargin)

    argParse = inputParser;
    argParse.addParameter('streamType',{'input' 'output'},@(x) ischar(x) & any(strcmp({'input','output'},x)));
    argParse.addParameter('checkHigherDomain',false,@islogical);
    argParse.addParameter('checkHash',true,@islogical);
    argParse.addParameter('isProbe',false,@islogical);
    argParse.parse(varargin{:});

    streamType = argParse.Results.streamType; if ~iscell(streamType), streamType = {streamType}; end

    fileList = '';

    % If fully specified
    streamName = strsplit(streamName,'.'); streamName = streamName{end};

    % Locate streamDescriptor
    for io = streamType
        logging.info('Locating %s stream %s...',io{1},streamName);

        % locate stream and make sure that streamName corresponds to the updated name if renamed
        selectStream = arrayfun(@(s) any(strcmp(s.name,streamName)), rap.tasklist.currenttask.([io{1} 'streams']));
        if ~any(selectStream), continue;
        else
            stream = rap.tasklist.currenttask.([io{1} 'streams'])(selectStream);
            streamName = stream.name; if iscell(streamName), streamName = streamName{1}; end
            switch io{1}
                case 'input', streamDomain = stream.streamdomain;
                case 'output', streamDomain = stream.domain;
            end
        end

        % locate streamfolder
        deps = getDependencyByDomain(rap,streamDomain,domain,indices);
        taskPath = arrayfun(@(d) readLink(getPathByDomain(rap,streamDomain,deps(d,:))),1:size(deps,1),'UniformOutput',false);

        streamDescriptor = cellstr(spm_select('FPList',taskPath,sprintf('^stream_%s_%s.*.txt$',streamName,io{1})));
        if ~isempty(streamDescriptor{1}), break; end
    end
    if ~isempty(streamDescriptor{1})
        logging.info('\tFound at%s',sprintf(' %s',streamDescriptor{:}));
        if argParse.Results.isProbe, fileList = 'x'; return; end
    else
        if ~argParse.Results.isProbe, logging.error('\tNo %s stream %s is found',io{1},streamName);
        else, logging.info('\tNo %s stream %s is found',io{1},streamName); return;
        end
    end

    fileList = {};
    hashList = {};
    for s = streamDescriptor'
        taskPath = spm_file(s{1},'path');

        % Check hash
        inStream = strsplit(fileRetrieve(s{1},rap.options.maximumretry,'content'),'\n');
        descHash = regexp(inStream{1},'(?<=(#\t))[0-9a-f]*','match');
        if ~isempty(descHash)
            hashList = [hashList descHash(1)];
            fileList = [fileList; reshape(inStream(2:end-1),[],1)]; % last is newline
            fileHash = getHashByFiles(fileList,'localroot',taskPath);
            if argParse.Results.checkHash && ~strcmp(descHash{1},fileHash), logging.error('%s stream %s has changed since its retrieval',io{1},streamName); end
            fileList = fullfile(taskPath,fileList);
        else
            if ~argParse.Results.isProbe, logging.error('\t%s stream %s is empty',io{1},streamName);
            else, logging.info('\t%s stream %s is empty',io{1},streamName); return;
            end
        end
    end

end

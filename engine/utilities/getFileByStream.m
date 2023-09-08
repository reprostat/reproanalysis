% Get file(s) from input- or outputstream
%  function getFileByStream(rap,domain,indices,streamName,['streamType','input'|'output'],['content',{<content1>[,<content2> ...]}],['checkHash',false|true],['isProbe',false|true])
%  e.g.,
%   getFileByStream(rap,'subject',[1],'structural')
%   getFileByStream(rap,'subject',[1],'native_segmentations','content',{'GM'})
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
    argParse.addParameter('content',{},@iscellstr);
    argParse.addParameter('checkHigherDomain',false,@islogical);
    argParse.addParameter('checkHash',true,@islogical);
    argParse.addParameter('isProbe',false,@islogical);
    argParse.parse(varargin{:});

    if ~rap.options.checkinputstreamconsistency, argParse.Results.checkHash = false; end

    streamType = argParse.Results.streamType; if ~iscellstr(streamType), streamType = cellstr(streamType); end

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

        if lookFor(streamName,'.')
            streamName = strsplit(streamName,'.'); [streamSource, streamName] = deal(streamName{:});
        else
            streamSource = '.*';
        end

        streamDescriptor = cellstr(spm_select('FPList',taskPath,sprintf('^stream_%s_%sfrom_%s\\.txt$',streamName,io{1},streamSource)));
        if ~isempty(streamDescriptor{1}), break; end
    end
    if exist('streamDescriptor','var') && ~isempty(streamDescriptor{1})
        logging.info('\tFound at%s',sprintf(' %s',streamDescriptor{:}));
        if argParse.Results.isProbe, fileList = 'x'; return; end
    else
        if ~argParse.Results.isProbe, logging.error('\tNo %s stream %s is found',io{1},streamName);
        else, logging.info('\tNo %s stream %s is found',io{1},streamName); return;
        end
    end

    fileList = struct();
    hashList = struct();
    for s = streamDescriptor'
        taskPath = spm_file(s{1},'path');

        % Read stream
        try
            inStream = readStream(s{1},rap.options.maximumretry);
        catch
            if ~argParse.Results.isProbe, logging.error('\tunable to read %s stream %s',io{1},streamName);
            else, logging.info('\tunable to read %s stream %s',io{1},streamName); return;
            end
        end

        % Filter for content
        if ~isempty(argParse.Results.content)
            missingContent = strjoin(setdiff(argParse.Results.content,fieldnames(inStream)),',');
            if ~isempty(missingContent)
                if ~argParse.Results.isProbe, logging.error('\t%s stream %s has no content %s',io{1},streamName,missingContent);
                else, logging.info('\t%s stream %s has no content %s',io{1},streamName,missingContent); return;
                end
            end
            inStream = rmfield(inStream,setdiff(fieldnames(inStream),argParse.Results.content));
        end

        % Process stream
        for f = fieldnames(inStream)'
            if argParse.Results.checkHash
                if ~strcmp(inStream.(f{1}).hash,getHashByFiles(inStream.(f{1}).files,'localroot',taskPath))
                    logging.error('%s stream %s.%s has changed since its retrieval',io{1},streamName,f{1});
                end
            end
            if ~isfield(fileList,f{1})
                fileList.(f{1}) = fullfile(taskPath,inStream.(f{1}).files);
                hashList.(f{1}) = cellstr(inStream.(f{1}).hash);
            else
                fileList.(f{1}) = [fileList.(f{1}); fullfile(taskPath,inStream.(f{1}).files)];
                hashList.(f{1}) = [hashList.(f{1}); cellstr(inStream.(f{1}).hash)];
            end
        end

    end
    if numel(fieldnames(fileList)) == 1 && strcmp(fieldnames(fileList),'files')
        fileList = fileList.files;
        hashList = hashList.files;
    end
end

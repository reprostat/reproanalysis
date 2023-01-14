function hashMD5 = getHashByFiles(fileList, varargin)

    argParse = inputParser;
    argParse.addParameter('localroot','',@ischar);
    argParse.addParameter('tocheck','data',@(x) ischar(x) & any(strcmp({'data','filestat'},x)));
    argParse.parse(varargin{:});

    if (~iscell(fileList)), fileList = cellstr(fileList); end
    if ~isempty(argParse.Results.localroot), fileList = fullfile(argParse.Results.localroot,fileList); end

    if any(cellfun(@(pth) ~exist(pth,'file'), fileList))
        logging.error('Some files do not exist');
    end

    % Loop across files
    md = hashClass();
    for pth = reshape(fileList,1,[])
        switch argParse.Results.tocheck
            case 'data'
                md.update(pth{1});
            case 'filestat'
                filestat = dir(pth{1});
                md.update([num2str(filestat.date) num2str(filestat.bytes)])
         end
    end
    hashMD5 = md.getHash();
end

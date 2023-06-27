function resp = fileRetrieve(fname,varargin)

    argParse = inputParser;
    argParse.addOptional('maximumRetry',0,@isnumeric);
    argParse.addOptional('toRespond','state',@(x) ischar(x) & any(strcmp({'state','content'},x)));
    argParse.parse(varargin{:});

    for r = 0:argParse.Results.maximumRetry
        resp = exist(fname,'file');
        if resp
            switch argParse.Results.toRespond
                case 'state'
                    resp = true;
                    break
                case 'content'
                    try resp = fileread(fname); catch, resp = ''; end
                    if ~isempty(resp), break; end
            end
        else
            resp = '';
        end
        pause(1);
        if r < argParse.Results.maximumRetry, logging.info('\tretry #%d',r+1); end
    end
    if isempty(resp), logging.error('Could not find or read %s', fname); end
end

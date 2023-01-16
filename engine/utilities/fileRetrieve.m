function resp = fileRetrieve(fname,varargin)

    argParse = inputParser;
    argParse.addOptional('maximumRetry',0,@isnumeric);
    argParse.addOptional('toRespond','state',@(x) ischar(x) & any(strcmp({'state','content'},x)));
    argParse.parse(varargin{:});

    resp = '';
    for r = 0:argParse.Results.maximumRetry
        resp = exist(fname,'file');
        if resp
            switch argParse.Results.toRespond
                case 'state'
                    resp = true;
                    break
                case 'content'
                    try, resp = fileread(fname); catch, end
                    if ~isempty(resp), break; end
            end
        end
        pause(1);
    end
    if isempty(resp) || ~resp, logging.error('Could not find or read %s - Are you sure it is in your path?', fname); end
end

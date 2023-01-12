function isFound = fileRetrieve(fname,maximumretry)
    if nargin < 2, maximumretry = 0; end
    if ~exist(fname,'file')
        isFound = false;
        if maximumretry
            retry = 0;
            while ~isFound && (retry < maximumretry)
                isFound = exist(fname,'file');
                retry = retry + 1;
                pause(1);
            end
        end
        if ~isFound, logging.error('Could not find %s - Are you sure it is in your path?', fname); end
    end
end

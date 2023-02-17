% checks a directory is made - if not makes it

function [resp, mkdirMsg] = dirMake(dirname)
    if ~exist(dirname,'dir')
        try
           [~, mkdirMsg] = mkdir(dirname);
        catch
            logging.error('Problem making directory %s',dirname);
        end
        resp = true; % created
    else
        resp = false; % not created
        mkdirMsg = sprintf('%s already exists',dirname);
    end
end

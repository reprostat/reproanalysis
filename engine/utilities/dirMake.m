% checks a directory is made - if not makes it

function [resp mkdirMsg] = dirMake(dirname)
    if ~exist(dirname,'dir')
        try
           [mkdirStatus, mkdirMsg] = mkdir(dirname);
        catch
            logging.error(true,sprintf('Problem making directory %s',dirname));
        end
        resp = true; % created
    else
        resp = false; % not created
    end
end

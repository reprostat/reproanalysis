% checks a directory is made - if not makes it

function resp = makedir(dirname)
    if ~exist(dirname,'dir')
        try
            mkdir(dirname);
        catch
            logging.error(true,sprintf('Problem making directory %s',dirname));
        end
        resp = true; % created
    else
        resp = false; % not created
    end
end

function reproa = reproaSetup()
% Reproducible Analysis - wrapper around reproaClass to ensure clean start with toolboxes in path

    global reproa

    if isobject(reproa)
        try rap = evalin('base','rap');
        catch, rap = []; end
        logging.warning(rap,false,'Previous execution of aa was not closed!')
        logging.warning(rap,false,'Killing jobs and restoring path settings for both linux and MATLAB...!')
        reproa.close('restorepath',true,'restorewarnings',true,'killjobs',true);
        logging.warning(rap,false,'Done!')
    else
        addpath(fullfile(fileparts([mfilename('fullpath') '.m']),'external','toolboxes'));
        reproa = reproaClass();
    end

end

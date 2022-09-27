function reproa = reproaSetup()
% Reproducible Analysis - wrapper around reproaClass to ensure clean start with toolboxes in path

    global reproa

    if isobject(reproa)
        logging.warning('Previous execution of aa was not closed!')
        logging.warning('Killing jobs and restoring path settings for both linux and MATLAB...!')
        reproa.close('restorepath',true,'restorewarnings',true,'killjobs',true);
        logging.warning('Done!')
    else
        addpath(fullfile(fileparts([mfilename('fullpath') '.m']),'external','toolboxes'));
        reproa = reproaClass();
    end

end

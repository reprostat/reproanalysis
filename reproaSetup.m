function reproa = reproaSetup()
% Reproducible Analysis - wrapper around reproaClass to ensure clean start with toolboxes in path

    global reproa

    if isobject(reproa) && strcmp(reproa.status, 'loaded')
        logging.warning('Previous execution of aa was not closed!')
        logging.warning('Killing jobs and restoring path settings for both linux and MATLAB...!')
        reproa.close('restorepath',true,'restorewarnings',true,'killjobs',true);
        logging.warning('Done!')
    else
        addpath(fullfile(fileparts([mfilename('fullpath') '.m']),'external','toolboxes'));
        reproa = reproaClass();
    end

end

%!test
%!  reproa = reproaSetup();
%!  global reproacache
%!  assert(isa(reproacache,'cacheClass'))
%!  reproa.unload();
%!  global reproacache
%!  assert(~isa(reproacache,'cacheClass') & isempty(reproacache))
%!  reproa.reload(true);
%!  reproacache = evalin('base','reproacache')
%!  assert(isa(reproacache,'cacheClass'))
%!  global reproaworker
%!  reproaworker = evalin('base','reproaworker')
%!  reproa.close()

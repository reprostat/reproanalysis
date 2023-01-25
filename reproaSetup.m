function reproaSetup()
% Reproducible Analysis - wrapper around reproaClass to ensure clean start with toolboxes in path
    REQUIREDOCTAVEPACKAGES = {...
        'video','creating videos for checking registrations';...
        'statistics','stats on diagnostics';...
        };

    global reproacache

    if isa(reproacache,'cacheClass')
        reproa = reproacache('reproa');
        if strcmp(reproa.status, 'loaded')
            logging.warning('Previous execution of aa was not closed!')
            logging.warning('Killing jobs and restoring path settings for both linux and MATLAB...!')
            reproa.close('restorepath',true,'restorewarnings',true,'killjobs',true);
            logging.warning('Done!')
        end
    end

    addpath(fullfile(fileparts([mfilename('fullpath') '.m']),'engine'));
    addpath(fullfile(fileparts([mfilename('fullpath') '.m']),'external','toolboxes'));

    reproa = reproaClass();
    reproacache('reproa') = reproa;

    % Check Octave depedencies
    if isOctave()
        logging.info('Checking required Octave packages...');
        [~,pkgInfo] = pkg('list');
        for indP = 1:size(REQUIREDOCTAVEPACKAGES,1)
            pkgName = REQUIREDOCTAVEPACKAGES{indP,1};
            logging.info('\t%s\t- %s',REQUIREDOCTAVEPACKAGES{indP,:});
            selP = cellfun(@(p) strcmp(p.name,pkgName), pkgInfo);
            if any(selP)
                toLoad = ~pkgInfo{selP}.loaded;
            else
                logging.info('\t\tInstalling...');
                pkg('install','-forge',pkgName);
                toLoad = true;
            end
            if toLoad
                logging.info('\t\tLoading...');
                pkg('load',pkgName);
            end
        end
    end

end

%!test
%!  reproa = reproaSetup();
%!  global reproacache
%!  assert(isa(reproacache,'cacheClass'),'Cache is not initialised')
%!  assert(isa(reproacache('toolbox.spm'),'spmClass'),'SPM is not loaded')
%!  reproa.unload();
%!  global reproacache
%!  assert(~isa(reproacache,'cacheClass') & isempty(reproacache),'Unload failed to clear cache')
%!  reproa.reload(true);
%!  reproacache = evalin('base','reproacache');
%!  assert(isa(reproacache,'cacheClass'),'Cache is not reloaded')
%!  global reproaworker
%!  reproaworker = evalin('base','reproaworker');
%!  reproa.close()

function reproaSetup(varargin)
% Reproducible Analysis - wrapper around reproaClass to ensure clean start with toolboxes in path
%
% reproaSetup(Name,Value)
% INPUT
%   Name - Value
%       'extensions' - extensionList, a cell array of reproa extensions to add.
%
% Current list of extensions:
%   - fconn         - functional connectivity
%   - freesurfer    - integrating FreeSurfer
%   - fsl           - integrating FSL and other related tools, such as ICA-AROMA


    % Check Octave depedencies
    REQUIREDOCTAVEPACKAGES = {...
        'io','Read and write parametersets and metadata';...
        'video','creating videos for checking registrations';...
        'statistics','stats on diagnostics';...
        };

    if exist ('OCTAVE_VERSION', 'builtin')
        fprintf('Checking required Octave packages...\n');
        [pkgInfo1,pkgInfo2] = pkg('list'); pkgInfo = [pkgInfo1 pkgInfo2]; % local and global packages
        for indP = 1:size(REQUIREDOCTAVEPACKAGES,1)
            pkgName = REQUIREDOCTAVEPACKAGES{indP,1};
            fprintf('\t%s\t- %s\n',REQUIREDOCTAVEPACKAGES{indP,:});
            selP = cellfun(@(p) strcmp(p.name,pkgName), pkgInfo);
            if any(selP)
                toLoad = ~pkgInfo{selP}.loaded;
            else
                fprintf('\t\tInstalling...\n');
                pkg('install','-forge',pkgName);
                toLoad = true;
            end
            if toLoad
                fprintf('\t\tLoading...\n');
                pkg('load',pkgName);
            end
        end
    end

    % Parse input
    argParse = inputParser;
    argParse.addParameter('extensions',{},@iscell);
    argParse.parse(varargin{:});

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

    addpath(fileparts([mfilename('fullpath') '.m']));
    addpath(fullfile(fileparts([mfilename('fullpath') '.m']),'engine'));
    addpath(fullfile(fileparts([mfilename('fullpath') '.m']),'external','toolboxes'));

    reproa = reproaClass();

    cellfun(@(ext) reproa.addExtension(ext), argParse.Results.extensions);

    reproacache('reproa') = reproa;
    reproacache('octavepackages') = REQUIREDOCTAVEPACKAGES(:,1);

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

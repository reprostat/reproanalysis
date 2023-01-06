function  localroot = getPathByDomain(rap,domain,indices,varargin)

argParse = inputParser;
argParse.addParameter('task',0,@isnumeric);
argParse.addParameter('remote','none',@ischar);
argParse.parse(varargin{:});

indTask = argParse.Results.task;
remotefilesystem = argParse.Results.remote;

% Numeric argument on the end corresponds to a specified input source
if indTask ~= 0

    if indTask < 0 % initialisation
        module = rap.tasklist.initialisation(-indTask);
        module.index = 1;
    else % main
        module = rap.tasklist.main(indTask);
    end

    % Get the basic root directory for the current filesystem
    switch remotefilesystem
        case 'none'
            if isfield(rap, 'internal')
                localroot = rap.internal.rap_initial.acqdetails.root;
            else
                localroot = rap.acqdetails.root;
            end
        otherwise
            if isfield(rap, 'internal')
                localroot = rap.internal.rap_initial.acqdetails.(remotefilesystem).root;
            else
                localroot = rap.acqdetails.(remotefilesystem).root;
            end
    end

    % Get analysis id and analysis id suffix
    if isfield(rap, 'internal')
        analysisid = rap.internal.rap_initial.directoryconventions.analysisid;
    else
        analysisid = rap.directoryconventions.analysisid;
    end
    if isfield(module.extraparameters,'rap')
        analysisid_suffix = module.extraparameters.rap.directoryconventions.analysisidsuffix;
    elseif isfield(rap, 'internal')
        analysisid_suffix = rap.internal.rap_initial.directoryconventions.analysisidsuffix;
    else
        analysisid_suffix = rap.directoryconventions.analysisidsuffix;
    end

    % Add suffixes
    localroot = fullfile(localroot,[analysisid analysisid_suffix],sprintf('%s_%05d',module.name,module.index));
else
    % otherwise, just use the root we've been given
    switch remotefilesystem
        case 'none'
            localroot = rap.acqdetails.root;
        otherwise
            localroot = rap.acqdetails.(remotefilesystem).root;
    end
end

if ~strcmp(domain,'study')
end

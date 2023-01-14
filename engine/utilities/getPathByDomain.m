function  localroot = getPathByDomain(rap,domain,indices,varargin)

    domaintree = findDomainDependency(domain,rap.paralleldependencies);
    if numel(indices) ~= (numel(domaintree)-1), logging.error('Expected %d indicies for domain "%s" but got %d',numel(domaintree)-1,domain,numel(indices)); end

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
        % analysisid is already included if within task
        if ~isfield(rap.tasklist,'currenttask'), localroot = fullfile(localroot, rap.directoryconventions.analysisid); end
    end

    for ind = 2:numel(domaintree)
        localroot = fullfile(localroot,getDirectoryByDomain(rap.acqdetails,domaintree{ind},indices(ind-1)));
    end

end

function directory = getDirectoryByDomain(acqdetails,domain,index)

    switch domain
        case 'subject'
            directory = acqdetails.subjects(index).subjname;

        case {'fmrirun' 'diffusionrun' 'specialrun' 'meegrun'}
            directory = acqdetails.([domain 's'])(index).name;

        case 'diffusionrunpedir '
            directory = sprintf('phaseencodedirection-%d',index);
    end

end

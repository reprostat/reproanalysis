function desc = getTaskDescription(rap,indices,whatToReturn)
    if nargin < 3, whatToReturn = 'full'; end

    desc = rap.tasklist.currenttask.name;
    if ~isempty(rap.tasklist.currenttask.extraparameters)
        desc = [desc rap.tasklist.currenttask.extraparameters.rap.directory_conventions.analysisid_suffix];
    end
    if strcmp(whatToReturn,'taskname'), return; end

    desc = [desc ': ' rap.tasklist.currenttask.description];
    if strcmp(whatToReturn,'taskdescription'), return; end

    domainList = findDomainDependency(rap.tasklist.currenttask.domain,rap.paralleldependencies.study);
    if isempty(domainList)
        if strcmp(whatToReturn,'indices'), desc = ''; return; end
    else
        domainNames = arrayfun(@(d) spm_file(getPathByDomain(rap,domainList{d},indices(1:d)),'basename'), 1:numel(indices),'UniformOutput',false);
        descIndices = strjoin(arrayfun(@(d) [domainList{d} ': ' domainNames{d}], 1:numel(domainList),'UniformOutput',false),', ');
        if strcmp(whatToReturn,'indices'), desc = descIndices; return; end

        desc = [desc ' - ' descIndices];
    end
end

function desc = getTaskDescription(rap,indices)
    desc = rap.tasklist.currenttask.description;
    domainList = findDomainDependency(rap.tasklist.currenttask.domain,rap.paralleldependencies.study);
    if ~isempty(domainList)
        domainNames = arrayfun(@(d) spm_file(getPathByDomain(rap,domainList{d},indices(1:d)),'basename'), 1:numel(indices),'UniformOutput',false);
        desc = [desc ' - ' strjoin(arrayfun(@(d) [domainList{d} ': ' domainNames{d}], 1:numel(domainList),'UniformOutput',false),', ')];
    end
end

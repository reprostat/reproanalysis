function indices = getIndicesByName(rap,domain,indices)

    domains = findDomainDependency(domain,rap.paralleldependencies); domains(1) = [];

    % named target domain
    if ischar(indices), indices = cellstr(indices); end
    if iscellstr(indices)
        for ind = 1:numel(indices)
            [~, indsDomain, namesDomain] = getNByDomain(rap,domains{ind},indices{1:ind-1});
            selDomain = strcmp(namesDomain,indices{ind});
            if ~any(selDomain), logging.error('%s %s not found',domains{ind},indices{ind}); end
            indices{ind} = indsDomain(selDomain);
        end
        indices = cell2mat(indices);
    end

end

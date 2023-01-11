function domaintree = findDomainDependency(domain,tree,root)

if nargin < 3, root = {}; end

domaintree = {};
if ~isempty(tree)
    for fn = fieldnames(tree)'
        if strcmp(fn{1},domain)
            domaintree={root{:} domain};
            break;
        else
            domaintree = findDomainDependency(domain,tree.(fn{1}),{root{:} fn{1}});
            if ~isempty(domaintree), break; end
        end
    end
end

end

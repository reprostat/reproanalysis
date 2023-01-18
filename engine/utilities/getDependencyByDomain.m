function deps = getDependencyByDomain(rap,sourceDomain,varargin)

    argParse = inputParser;
    argParse.addOptional('destinationDomain','study',@ischar)
    argParse.addOptional('destinationIndices',[],@isnumeric)
    argParse.parse(varargin{:});
    destinationDomain = argParse.Results.destinationDomain;
    destinationIndices = argParse.Results.destinationIndices;

    % identify difference in domain level between source and destination
    sourceDomainTree = findDomainDependency(sourceDomain,rap.paralleldependencies);
    destinationDomainTree = findDomainDependency(destinationDomain,rap.paralleldependencies);
    % Find the point where the source and destination branches converge
    for indCommon = 1:min(numel(sourceDomainTree),numel(destinationDomainTree))
        if ~strcmp(sourceDomainTree{indCommon},destinationDomainTree{indCommon})
            indCommon = indCommon-1;
            break
		end
	end

    if numel(destinationIndices) ~= (numel(destinationDomainTree)-1)
        logging.error('Expected %d indicies for domain "%s" but got %d',numel(destinationDomainTree)-1,destinationDomain,numel(destinationIndices));
	end

    % dependency: only relevant sources until the common point and all possible sources below
    if numel(sourceDomainTree) > indCommon % if the source domain is at a lower level -> all possible combination of sources from subsequent levels
        deps = cell(numel(sourceDomainTree)-indCommon,1);
        for indDomain = indCommon+1:numel(sourceDomainTree)
            depInd = indDomain-indCommon;
            deps{depInd}(1) = sourceDomainTree(indDomain);
            if depInd == 1
                [~,ind] = getNByDomain(rap,deps{depInd}{1},destinationIndices);
                deps{depInd}{2} = [repmat(destinationIndices,numel(ind),1) ind'];
            else
                deps{depInd}{2} = [];
                for i = 1:size(deps{depInd-1}{2},1)
                    [~,ind] = getNByDomain(rap,deps{depInd}{1},deps{depInd-1}{2}(i,:));
                    deps{depInd}{2} = [deps{depInd}{2};...
                            [repmat(deps{depInd-1}{2}(i,:),numel(ind),1) ind']
                        ];
                end
            end
        end
        deps = deps{end}{2};
    else % if the source domain is at the same or higher level -> only relevant sources as specified in the destinationIndices
        deps = destinationIndices(1:indCommon-1);
    end

end

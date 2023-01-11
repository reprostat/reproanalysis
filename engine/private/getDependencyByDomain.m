function deps = getDependencyByDomain(rap,sourceDomain,varargin)

    argParse = inputParser;
    argParse.addOptional('targetDomain','study',@ischar)
    argParse.addOptional('targetIndices',[],@isnumeric)
    argParse.parse(varargin{:});
    targetDomain = argParse.Results.targetDomain;
    targetIndices = argParse.Results.targetIndices;

    % identify difference in domain level between source and target
    sourceDomainTree = findDomainDependency(sourceDomain,rap.paralleldependencies);
    targetDomainTree = findDomainDependency(targetDomain,rap.paralleldependencies);
    % Find the point where the source and target branches converge
    for indCommon = 1:min(numel(sourceDomainTree),numel(targetDomainTree))
        if ~strcmp(sourceDomainTree{indCommon},targetDomainTree{indCommon})
            indCommon = indCommon-1;
            break
		end
	end

    if numel(targetIndices) ~= (numel(targetDomainTree)-1)
        logging.error('Expected %d indicies for domain "%s" but got %d',numel(targetDomainTree)-1,targetDomain,numel(targetIndices));
	end

    % dependency: only relevant sources until the common point and all possible sources below
    if numel(sourceDomainTree) > indCommon % if the source domain is at a lower level -> all possible combination of sources from subsequent levels
        deps = cell(numel(sourceDomainTree)-indCommon,1);
        for indDomain = indCommon+1:numel(sourceDomainTree)
            depInd = indDomain-indCommon;
            deps{depInd}(1) = sourceDomainTree(indDomain);
            if depInd == 1
                [~,ind] = getNByDomain(rap,deps{depInd}{1},targetIndices);
                deps{depInd}{2} = [repmat(targetIndices,numel(ind),1) ind'];
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
    else % if the source domain is at the same or higher level -> only relevant sources as specified in the targetIndices
        deps = targetIndices(1:indCommon-1);
    end

end

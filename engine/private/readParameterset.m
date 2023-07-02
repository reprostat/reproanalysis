function rap = readParameterset(parametersetFile)
    if exist(parametersetFile,'file'), xml = readxml(parametersetFile);
    else, logging.error('File %s not found', parametersetFile);
    end
    rap = processattributes(xml);
end

function node = processattributes(node)
if isstruct(node)
    if isfield(node,'COMMENT'), node = rmfield(node,'COMMENT');  end
    if isfield(node,'ATTRIBUTE')
        if isfield(node,'CONTENT')
            attr = node.ATTRIBUTE;
            node = node.CONTENT;
            if isfield(attr,'ui')
                switch attr.ui
                    case {'text' 'dir' 'dir_allowwildcards' 'dir_part_allowwildcards' 'dir_part' 'file'}
                        node = char(node);
                        if lookFor(node,pathsep), node = strsplit(node,pathsep); end
                        % TODO
                        %                     case {'dir_list','optionlist'}
                        %                     case {'structarray'}
                        %                     case {'intarray' 'rgb'}
                        %                     case {'double'}
                        %                     case {'int'}
                        %                     case {'yesno'}
                end
            end
            return
        else
            node = rmfield(node,'ATTRIBUTE');
        end
    end
    for f = fieldnames(node)'
        node.(f{1}) = cell2mat(arrayfun(@(x) processattributes(x), node.(f{1}), 'UniformOutput', false)); % deal with arrays
    end
end
end

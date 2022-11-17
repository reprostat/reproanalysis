function module = readModule(parametersetFile)
    module = struct('header',[],'hpc',[],'permanenceofoutput',[],'settings',[],'inputstreams',[],'outputstreams',[]);

    xml = readxml(parametersetFile);

    module.header = rmfield(xml.header.ATTRIBUTE,'desc');
    if isfield(xml,'hpc'), module.hpc = xml.hpc; end
    if isfield(xml,'permanenceofoutput'), module.permanenceofoutput = xml.permanenceofoutput; end
    if isfield(xml,'settings'), module.settings = processAttributes(xml.settings); end
    if isfield(xml,'inputstreams'), module.inputstreams = processStreams(xml.inputstreams.stream); end
    if isfield(xml,'outputstreams'), module.outputstreams = processStreams(xml.outputstreams.stream); end
end

function node = processAttributes(node)
if isstruct(node)
    if isfield(node,'COMMENT'), node = rmfield(node,'COMMENT');  end
    if isfield(node,'ATTRIBUTE')
        if isfield(node,'CONTENT')
            attr = node.ATTRIBUTE;
            node = node.CONTENT;
            if isa(node,'char') && contains(node,pathsep), node = strsplit(node,pathsep); end
            return
        else
            node = rmfield(node,'ATTRIBUTE');
        end
    end
    for f = fieldnames(node)'
        node.(f{1}) = cell2mat(arrayfun(@(x) processAttributes(x), node.(f{1}), 'UniformOutput', false)); % deal with arrays
    end
end
end

function node = processStreams(node)
    switch class(node)
        case 'char' % single stream without attributes
            node = struct(...
                'name',node,...
                'isessential',1,...
                'isrenameable',0 ...
                );
        case 'struct'
            if numel(node) > 1, node = arrayfun(@(x) processStreams(x), node);
            else
                node = struct(...
                    'name',node.CONTENT,...
                    'isessential',~isfield(node.ATTRIBUTE,'isessential') || node.ATTRIBUTE.isessential,...
                    'isrenameable',isfield(node.ATTRIBUTE,'isrenameable') && node.ATTRIBUTE.isrenameable ...
                    );
            end
        case 'cell'
            node = cellfun(@(x) processStreams(x), node);
    end
end


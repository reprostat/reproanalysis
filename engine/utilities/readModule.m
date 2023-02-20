function module = readModule(moduleFile)
    module = struct('name',spm_file(moduleFile,'basename'),'aliasfor','','index',[],'branchid',[],'extraparameters',[],'header',[],'hpc',[],'permanenceofoutput',[],'settings',[],'inputstreams',[],'outputstreams',[]);

    xml = readxml(moduleFile);

    module.header = xml.header.ATTRIBUTE;
    if isfield(xml,'hpc'), module.hpc = xml.hpc; end
    if isfield(xml,'permanenceofoutput'), module.permanenceofoutput = xml.permanenceofoutput; end
    if isfield(xml,'settings'), module.settings = processAttributes(xml.settings); end
    if isfield(xml,'inputstreams'), module.inputstreams = processStreams(xml.inputstreams.stream,module.header.domain); end
    if isfield(xml,'outputstreams'), module.outputstreams = processStreams(xml.outputstreams.stream,module.header.domain); end
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
        params = arrayfun(@(x) processAttributes(x), node.(f{1}), 'UniformOutput', false);
        if any(cellfun(@iscell, params))
            logging.info('%s has nested cell or object',f{1});
            cellfun(@disp,params);
        end
        node.(f{1}) = cell2mat(params); % deal with arrays
    end
end
end

function node = processStreams(node,moduleDomain)
    domain = moduleDomain;
    switch class(node)
        case 'char' % single stream without attributes
            node = struct(...
                'name',node,...
                'domain',domain,...
                'isessential',1,...
                'isrenameable',0, ...
                'tobemodified',1 ...
                );
        case 'struct' % with attributes
            if numel(node) > 1, node = arrayfun(@(x) processStreams(x,domain), node);
            else
                if isfield(node.ATTRIBUTE,'domain'), domain = node.ATTRIBUTE.domain; end
                node = struct(...
                    'name',node.CONTENT,...
                    'domain',domain,...
                    'isessential',~isfield(node.ATTRIBUTE,'isessential') || node.ATTRIBUTE.isessential,...
                    'isrenameable',isfield(node.ATTRIBUTE,'isrenameable') && node.ATTRIBUTE.isrenameable, ...
                    'tobemodified',~isfield(node.ATTRIBUTE,'tobemodified') || node.ATTRIBUTE.tobemodified ...
                    );
            end
        case 'cell'
            node = cellfun(@(x) processStreams(x,domain), node);
    end
end


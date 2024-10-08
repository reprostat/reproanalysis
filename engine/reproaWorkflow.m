% Load parameter defaults and tasklist into the rap structure
%
% FORMAT rap = reproaWorkflow(tasklist)
% Parameter defaults are loaded from ~/.reproa/reproa_parameters_user.xml
%   - tasklist: XML-file containing the list of modules
%
% FORMAT rap = reproaWorkflow(parameters,tasklist)
%   - parameters: XML-file containing the parameter defaults
%   - tasklist: XML-file containing the list of modules
%
% Tibor Auer 2022

function rap = reproaWorkflow(varargin)
    global reproacache
    assert(isa(reproacache,'cacheClass'),'reproa is not initialised -> run reproaSetup')
    reproa = reproacache('reproa');

    switch(numel(varargin))
        case 0
            warning('You must provide a tasklist to reproaWorkflow.\n');
        case 1
            parametersetFile = fullfile(reproa.configdir,reproa.parameterFile);
            tasklistFile = varargin{1};
        case 2
            parametersetFile = varargin{1};
            tasklistFile = varargin{2};
    end

    % Read parameterset
    rap = expandPathByVars(readParameterset(parametersetFile));
    % - extensions
    for extName = reproa.extensions
        paramExt = fullfile(reproa.toolPath,'extensions',extName{1},'parametersets',['parameters_' lower(extName{1}) '.xml']);
        if exist(paramExt,'file')
            rapExt = expandPathByVars(readParameterset(paramExt));
            % - add toolboxes (if any)
            if isfield(rapExt.directoryconventions,'toolbox')
                for tbx = reshape(rapExt.directoryconventions.toolbox,1,[])
                    if isempty(tbx.dir) % unspecified or uncustomised -> check main config
                        if ismember(tbx.name,{rap.directoryconventions.toolbox.name})
                            tbx = rap.directoryconventions.toolbox(strcmp({rap.directoryconventions.toolbox.name},tbx.name));
                        end
                    end
                    if isempty(tbx.dir) % still unspecified or uncustomised
                        extXML = strsplit(fileread(paramExt),'\n');
                        indName = find(lookFor(extXML, '>conn<'));
                        indTbxStart = find(lookFor(extXML, '<toolbox'));
                        indTbxEnd = find(lookFor(extXML, '</toolbox'));
                        indLines = indTbxStart(find(indTbxStart<indName,1,'last')): ...
                            indTbxEnd(find(indTbxEnd>indName,1,'first'));
                        logging.warning(['Toolbox %s for extension %s is not configured\n' ...
                            '\tYou need to add the corresponding toolbox entry in %s if you want to use it:\n\n' ...
                            strjoin(strrep(extXML(indLines),'></dir','>add path here</dir'),'\n') ...
                            '\n\n'], ...
                            tbx.name, extName{1}, parametersetFile);
                        continue;
                    end
                    if ~isfolder(tbx.dir), logging.error(['Toolbox %s for extension %s not found in %s\n' ...
                        '\tYou may need to correct the corresponding toolbox entry in %s'], ...
                        tbx.name, extName{1}, tbx.dir, parametersetFile);
                    end
                    logging.info('Adding toolbox %s for extension %s', tbx.name, extName{1})
                    reproa.addReproaToolbox(tbx);
                end
            end
            rap = structUpdate(rap,rapExt,'Mode','extend');
        end
    end

    rap.internal.parametersetFile = parametersetFile;
    rap.internal.tasklistFile = tasklistFile;

    % Read tasklist
    if ischar(tasklistFile)
        tasks = readParameterset(tasklistFile);
    elseif iscell(tasklistFile)
        tasks.module = readModuleList(tasklistFile);
    else
        logging.error('Unknown tasklist format');
    end
    if ~isfield(tasks.module,'branch') % no branches
        modules = tasks.module';
    else % process branches
        branchIDs = num2cell('abcdefghijklmnopqrstuvwxyz'); % CAVE: max 26 levels per branch
        branchid = branchIDs(1); analysisidsuffix = {''}; selectedruns = {'*'};
        modules = struct('name',{},'branchid',{},'extraparameters',{});

        while ~isempty(tasks.module)
            if ~isempty(tasks.module(1).name) % normal module
                for b = 1:numel(branchid) % add for all branches with corresponding parameters
                    modules(end+1).name = tasks.module(1).name;
                    modules(end).branchid = branchid{b};
                    modules(end).extraparameters.rap.directoryconventions.analysisidsuffix = analysisidsuffix{b};
                    modules(end).extraparameters.rap.acqdetails.selectedruns = selectedruns{b};
                end
                tasks.module(1) = [];
            else % branch
                branch = tasks.module(1).branch;
                tasks.module(1) = [];

                % update branch parameters
                branchid = strjoin_comb(branchid,branchIDs(1:numel(branch)));
                analysisidsuffix = strjoin_comb(analysisidsuffix,{branch.analysisidsuffix});
                if isfield(branch,'selectedruns')
                    selectedruns = strjoin_comb(selectedruns,{branch.selectedruns},true);
                else
                    selectedruns = strjoin_comb(selectedruns,repmat({''},1,numel(branch)));
                end

                % add modules within branches
                if isfield(branch,'module')
                    for b = 1:numel(branchid)
                        selb = strcmp(branchIDs, branchid{b}(end));
                        for m = branch(selb).module
                            modules(end+1).name = m.name;
                            modules(end).branchid = branchid{b};
                            modules(end).extraparameters.rap.directoryconventions.analysisidsuffix = analysisidsuffix{b};
                            modules(end).extraparameters.rap.acqdetails.selectedruns = selectedruns{b};
                        end
                    end
                end
            end
        end
    end

    % Process tasklist
    % - initialisation
    rap.tasklist.initialisation = [readModule('reproa_checkparameters.xml') readModule('reproa_makeanalysisroot.xml')];

    % - main
    rap.tasklist.main = rap.tasklist.initialisation(false);
    for m = reshape(modules,1,[])
        if isfield(m,'aliasfor') && ~isempty(m.aliasfor)
            rap.tasklist.main(end+1) = readModule([m.aliasfor '.xml']);
            rap.tasklist.main(end).aliasfor = rap.tasklist.main(end).name;
            rap.tasklist.main(end).name = m.name;
        else
            rap.tasklist.main(end+1) = readModule([m.name '.xml']);
        end
        rap.tasklist.main(end).index = sum(strcmp({rap.tasklist.main.name},m.name));
        if exist('branchIDs','var') % branches
            rap.tasklist.main(end).branchid = m.branchid;
            rap.tasklist.main(end).extraparameters = m.extraparameters;
        end
        if isfield(rap.tasklist.main(end),'settings') && ~isempty(rap.tasklist.main(end).settings)
            rap.tasksettings.(m.name)(rap.tasklist.main(end).index) = rap.tasklist.main(end).settings;
        end
    end
end

function strlist = strjoin_comb(strlist1,strlist2,doReplace)
    if nargin < 3, doReplace = false; end
    strlist = {};
    for s1 = strlist1
        for s2 = strlist2
            if doReplace
                if ~isempty(s2{1}), strlist{end+1} = s2{1};
                else, strlist{end+1} = s1{1};
                end
            else
                strlist{end+1} = [s1{1} s2{1}];
            end
        end
    end
end

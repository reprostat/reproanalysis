function rap = reproaConnect(rap,varargin)
% Specify and connect the input remote workflow and connect subjects and
% run-level data, so that internal functions, such as getNByDomain and
% getRunName works.
% CAVE: The data in rap.acqdetails.subjects serves as placeholders and MUST NOT
% be trusted.

argParse = inputParser;
argParse.addParameter('subjects','*',@(x) (iscell(x) || ischar(x)))
argParse.addParameter('runs','*',@(x) (iscell(x) || ischar(x)))
argParse.parse(varargin{:});

global reproacache

%% Collect all remote raps
for r = 1:numel(rap.acqdetails.input.remoteworkflow)
    remote = rap.acqdetails.input.remoteworkflow(r);
    dat = load(fullfile(remote.path,'rap.mat'));
    remote.rap = dat.rap;
    if isempty(remote.maxtask)
        remote.maxtask = numel(remote.rap.tasklist.main);
    else
        taskName = regexp(remote.maxtask,'.*(?=_0)','match','once');
        taskIndex = str2double(regexp(remote.maxtask,'(?<=_)[0-9]{5}','match','once'));
        remote.maxtask = find(strcmp({remote.rap.tasklist.main.name},taskName) &...
                              [remote.rap.tasklist.main.index] == taskIndex);
    end
    reproacache(sprintf('input.remote%d',r)) = remote;
end

%% Collect all runtypes and runs
runtypes = fieldnames(rap.acqdetails); runtypes = runtypes(endsWith(runtypes,'runs') & ~strcmp(runtypes,'selectedruns'));
for t = runtypes', remoteRuns.(t{1}) = {}; end
for r = 1:numel(rap.acqdetails.input.remoteworkflow)
    remote = reproacache(sprintf('input.remote%d',r));
    for f = runtypes'
        remoteRuns.(f{1}) = [remoteRuns.(f{1}) {remote.rap.acqdetails.(f{1}).name}];
    end
end

% Remove empty runtypes
runtypes = runtypes(cellfun(@(t) ~isempty(remoteRuns.(t){1}),runtypes))';

% Add runtpes and runs
for t = runtypes
    selectedRuns = unique(remoteRuns.(t{1}));
    if ~strcmp(argParse.Results.runs,'*')
        selectedRuns = intersect(selectedRuns,argParse.Results.runs);
    end
    for run = selectedRuns
        rap = addRun(rap,strrep(t{1},'runs',''),run{1});
    end
end

%% Add subjects and run-level data placeholders
for r = numel(rap.acqdetails.input.remoteworkflow):-1:1 % ensure earlier connection takes precendence
    remote = reproacache(sprintf('input.remote%d',r));
    allRemoteSubjects = {remote.rap.acqdetails.subjects.subjname};
    if ~strcmp(argParse.Results.subjects,'*')
        selectedSubjects = intersect(allRemoteSubjects,argParse.Results.subjects);
    else
        selectedSubjects = allRemoteSubjects;
    end

    for subj = selectedSubjects
        if isempty(rap.acqdetails.subjects(1).subjname) % first subject
            localSub = 1;
        else
            localSub = find(strcmp({rap.acqdetails.subjects.subjname},subj{1}));
            if isempty(localSub) % new subject
                localSub = numel(rap.acqdetails.subjects)+1;
            end
        end
        rap.acqdetails.subjects(localSub).subjname = subj{1};
        rap.acqdetails.subjects(localSub).subjid = subj; % emulate single visit
        remoteSub = find(strcmp(allRemoteSubjects,subj{1}));

        for t = runtypes
            % -- remote run names
            [~,localindRemoteRunInds] = ismember({remote.rap.acqdetails.(t{1}).name},...
                                                 {rap.acqdetails.(t{1}).name});

            % -- remote run indices
            [~, indRemoteRun] = getNByDomain(remote.rap,t{1}(1:end-1),remoteSub);
            % -- map remote to local
            for r = indRemoteRun
                [~, series] = getSeriesNumber(remote.rap,remoteSub,strrep(t{1},'runs','series'),r);
                rap.acqdetails.subjects(localSub).(strrep(t{1},'runs','series')){1}{localindRemoteRunInds(r)} = series;
            end
        end
    end
end

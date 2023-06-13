function rap = processBIDS(rap,varargin)
% Allow specify Subjects, Sessions and Events from Brain Imaging Data Structure (BIDS)
%
%       rap = processBIDS(rap,[[<Name>,<Value>][,<Name>,<Value>]...])
%
% Required:
%     - rap.directory_conventions.rawdatadir: path to BIDS
%
% Relevant rap sub-fields:
%     - rap.acqdetails.input.selectedsubjects:
%           cell or char array of subjects to process
%     - rap.acqdetails.input.selectedsessions:
%           cell or char array of sessions to process
%     - rap.acqdetails.input.combinemultiple:
%           Combines multiple visits per subjects (true) or treat them as separate subjects (false) (default = false)
%     - rap.acqdetails.input.selectedruns:
%           selection of a subset of tasks/runs based on their names (e.g. '<task name>-<run name>')
%           - elements are strings: selecting for preprocessing and analysis
%           - elements are cells:
%               - one cell is a selection for one "reproa_firstlevelmodel" (in the tasklist)
%               - tasks/runs selected for any "reproa_firstlevelmodel" are pre-processed
%           (default = [], all tasks/runs are selected for both preprocessing and analysis)
%     - rap.acqdetails.input.correctEVfordummies: whether number of
%           dummies should be take into account when defining onset times (default = true);
%           Also requires:
%               - rap.tasksettings.<data module>.numdummies: number of (acquired) dummy scans (default = 0);
%               - "repetition_time" (TR) specified in JSON header
%
%  Optional parameters (Name-Value pairs): specific for BIDS and add flexibility in the handling
%       of modelling (i.e., tsv) data. They can be combined as needed.
%
%     - 'omitModeling':
%           return w/o processing modeling data (default = false)
%     - 'regcolumn':
%           column in events.tsv to use for firstlevel model (default = 'trial_type')
%     - 'stripEventNames':
%           strip special characters from event names (default = false)
%     - 'convertEventsToUppercase':
%           convert event names to uppercase as required for contrast specification based on
%           event names (default = false)
%     - 'maxEventNameLength:'
%           truncate event names longer than the specified value (default = inf)
%     - 'omitNullEvents':
%           do not add "null" events to model (default = false)
%
% N.B.: MRI only
%

global BIDSsettings;
global reproacache

if ~exist('spm')
    if isa(reproacache,'cacheClass')
        tbSPM = reproacache('toolbox.spm');
        tbSPM.load();
    else
        logging.error('SPM not found and reproa cannot load it');
    end
end

%% Initialise parameters
argParse = inputParser;
argParse.addParameter('omitModeling',false,@(x) islogical(x) || isnumeric(x));
argParse.addParameter('regcolumn','trial_type',@ischar);
argParse.addParameter('stripEventNames',false,@(x) islogical(x) || isnumeric(x));
argParse.addParameter('omitNullEvents',false,@(x) islogical(x) || isnumeric(x));
argParse.addParameter('convertEventsToUppercase',false,@(x) islogical(x) || isnumeric(x));
argParse.addParameter('maxEventNameLength',inf,@isnumeric);
argParse.parse(varargin{:});

BIDSsettings = argParse.Results;
BIDSsettings.combinemultiple = rap.acqdetails.input.combinemultiple;

if BIDSsettings.combinemultiple
    logging.warning('You have selected combining multiple BIDS sessions!\n\tMake sure that you have also set rap.options.autoidentify* appropriately!\n\tN.B.: <runname> = <BIDS task+run name>_<BIDS session name>');
else
    logging.warning('You have selected not to combining multiple BIDS sessions!\n\tN.B.: <subject name> = <BIDS subject name>_<BIDS session name>');
end

% adjust rap
% - manual subject name
rap.directoryconventions.subjectdirectoryformat = 3;
rap.directoryconventions.subjectoutputformat = 'sub-%s';

% - ensure that models (if any) use seconds
if isfield(rap.tasksettings,'reproa_firstlevelmodel') && ~BIDSsettings.omitModeling
    for m = 1:numel(rap.tasksettings.reproa_firstlevelmodel)
        rap.tasksettings.reproa_firstlevelmodel(m).xBF.UNITS  ='secs';
    end
end

%% Parse (MRI only)
BIDS = bids.layout(rap.directoryconventions.rawdatadir);

% Look for subjects
SUBJ = bids.query(BIDS, 'subjects');
if ~isempty(rap.acqdetails.input.selectedsubjects), SUBJ = intersect(SUBJ,rap.acqdetails.input.selectedsubjects); end
if isempty(SUBJ), logging.error('no subjects found in directory %s', rap.directoryconventions.rawdatadir); end

SESS = bids.query(BIDS, 'sessions'); if isempty(SESS), SESS = {''}; end
if ~isempty(rap.acqdetails.input.selectedsessions), SESS = intersect(SESS,rap.acqdetails.input.selectedsessions); end

MODs = bids.query(BIDS, 'modalities');
SFXs = bids.query(BIDS, 'suffixes');

for subj = SUBJ
    if BIDSsettings.combinemultiple
        structuralimages = {};
        fmriimages = {};
        fieldmapimages = {};
        diffusionimages = {};
        specialimages = {};
    else
        structuralimages = repmat({{}},1,numel(SESS));
        fmriimages = repmat({{}},1,numel(SESS));
        fieldmapimages = repmat({{}},1,numel(SESS));
        diffusionimages = repmat({{}},1,numel(SESS));
        specialimages = repmat({{}},1,numel(SESS));
    end

    % anat
    if ismember('anat',MODs)
        for sfx = intersect(strsplit(rap.tasksettings.reproa_fromnifti_structural.sfxformodality,':'), bids.query(BIDS, 'suffixes', 'modality', 'anat'),'stable')
            for sessInd = 1:numel(SESS)
                image = bids.query(BIDS, 'data', 'sub',subj{1}, 'ses',SESS{sessInd}, 'suffix',sfx{1});
                if isempty(image), continue; end
                hdr = bids.query(BIDS, 'metadata', 'sub',subj{1}, 'ses',SESS{sessInd}, 'suffix',sfx{1});
                if isempty(fieldnames(hdr)), hdr = [];
                else, hdr = repmat({hdr},1,numel(image));
                end
                if BIDSsettings.combinemultiple
                    structuralimages = horzcat(structuralimages,struct('fname',image{1},'hdr',hdr));
                else
                    structuralimages{sessInd} = horzcat(structuralimages{sessInd},struct('fname',image{1},'hdr',hdr));
                end
            end
        end
    end

    % fmri
    if ismember('func',MODs) && ismember('bold',SFXs)
        for task = bids.query(BIDS, 'tasks')
            for sessInd = 1:numel(SESS)
                RUNS = bids.query(BIDS, 'runs', 'ses', SESS{sessInd}, 'task', task{1}); if isempty(RUNS), RUNS = {''}; end

                for run = RUNS
                    if ~isempty(run{1})
                        taskname = [task{1} '-' run{1}];
                    else
                        taskname = task{1};
                    end
                    if BIDSsettings.combinemultiple && ~isempty(SESS{sessInd})
                        taskname = [taskname '_' SESS{sessInd}];
                    end

                    % Skip?
                    if ~isempty(rap.acqdetails.selectedruns) && ~any(strcmp({rap.acqdetails.fmrirun(rap.acqdetails.selectedruns).name},taskname)), continue; end

                    rap = addRun(rap, 'fmri', taskname);

                    image = bids.query(BIDS, 'data', 'sub', subj{1}, 'ses',SESS{sessInd}, 'suffix', 'bold', 'task', task{1});
                    hdr = bids.query(BIDS, 'metadata', 'sub', subj{1}, 'ses',SESS{sessInd}, 'suffix', 'bold', 'task', task{1}); if isempty(fieldnames(hdr)), hdr = []; end
                    eventfile = bids.query(BIDS, 'data', 'sub', subj{1}, 'ses',SESS{sessInd}, 'suffix', 'events', 'task', task{1});

                    if BIDSsettings.combinemultiple
                        fmriimages = horzcat(fmriimages,struct('fname',image{1},'hdr',hdr));
                    else
                        fmriimages{sessInd} = horzcat(fmriimages{sessInd},struct('fname',image{1},'hdr',hdr));
                    end

                    if ~BIDSsettings.omitModeling
                        subjname = subj{1};
                        if ~BIDSsettings.combinemultiple && ~isempty(SESS{sessInd}), subjname = [subjname '_' SESS{sessInd}]; end

                        TR = 0; if isfield(hdr,'RepetitionTime'), TR = hdr.RepetitionTime; end

                        % locate firstlevelmodel modules
                        indModel = [];
                        for stageInd = find(strcmp({rap.tasklist.main.name},'reproa_firstlevelmodel'))
                            if isstruct(rap.tasklist.main(stageInd).extraparameters)
                                runs = strsplit(rap.tasklist.main(stageInd).extraparameters.rap.acqdetails.selectedruns,' ');
                            else
                                runs = {rap.acqdetails.fmriruns.name};
                            end
                            if any(strcmp(runs,'*')) || any(strcmp(runs,taskname)), indModel(end+1) = rap.tasklist.main(stageInd).index; end
                        end

                        if isempty(eventfile), logging.warning('No event found for subject %s task/run %s\n',subjname,taskname);
                        else
                            if ~TR, logging.warning('No (RepetitionTime in) header found for subject %s task/run %s\n\tNo correction of EV onset for dummies is possible!',subjname,taskname); end
                            tDummies = rap.acqdetails.input.correctEVfordummies*rap.tasksettings.reproa_fromnifti_fmri.numdummies*TR;

                            % process events
                            EVENTS = bids.util.tsvread(eventfile{1});
                            allEvents = EVENTS.(BIDSsettings.regcolumn);
                            eventNames = unique(allEvents);
                            for n = 1:numel(eventNames)
                                indEvent = strcmp(allEvents,eventNames{n});
                                eventOnsets{n} = EVENTS.onset(indEvent);
                                eventDurations{n} = EVENTS.duration(indEvent);
                            end

                            % - preprocess even names
                            if BIDSsettings.stripEventNames
                                eventNames = regexprep(eventNames,'[^a-zA-Z0-9]','');
                            end
                            if BIDSsettings.convertEventsToUppercase
                                eventNames = upper(eventNames);
                            end
                            if BIDSsettings.maxEventNameLength < Inf
                                eventNames = cellfun(@(x) x(1:min(BIDSsettings.maxEventNameLength,length(x))), eventNames,'UniformOutput',false);
                            end

                            % - add events to the models
                            for m = indModel
                                for e = 1:numel(eventNames)
                                    if BIDSsettings.omitNullEvents && strcmpi(eventNames{e},'null'), continue; end
                                    rap = addEvent(rap,sprintf('reproa_firstlevelmodel_%05d',m),subjname,taskname,eventNames{e},eventOnsets{e}-tDummies,eventDurations{e});
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    % fieldmaps
    if ismember('fmap',MODs)
        for sessInd = 1:numel(SESS)
            % dual-echo
            for fmap = reshape(bids.query(BIDS, 'data', 'sub',subj{1}, 'ses',SESS{sessInd}, 'modality','fmap', 'suffix','phasediff'),1,[])
                images = cell(1,3);
                images(1) = fmap;
                images{2} = strrep(images{1},'phasediff','magnitude1');
                images{3} = strrep(images{1},'phasediff','magnitude2');
                if ~exist(images{3},'file'), images(end) = []; end
                hdr = jsonread(strrep(images{1},'.nii.gz','.json'));
                hdr.EchoTime = [hdr.EchoTime1 hdr.EchoTime2];
                runName = '';
                if isfield(hdr,'IntendedFor'), runName = regexp(hdr.IntendedFor,'(?<=task-)[^_]*','match','once'); end
                if isempty(runName)
                    logging.warning('No task specification found for fieldmap %s -> assuming all run',images{1});
                    runName = '*';
                end
                runName = ['fmrirun-' runName];

                rapFmap.fname = images;
                rapFmap.hdr = hdr;
                rapFmap.run = runName;

                if BIDSsettings.combinemultiple
                    rapFmap.run = [rapFmap.run '_' SESS{sessInd}];
                    fieldmapimages = horzcat(fieldmapimages,rapFmap);
                else
                    fieldmapimages{sessInd} = horzcat(fieldmapimages{sessInd},rapFmap);
                end
            end

            % topup
            if ~isempty(bids.query(BIDS, 'metadata', 'sub',subj{1}, 'ses',SESS{sessInd}, 'modality','fmap', 'suffix','epi'))
                DIRs = bids.query(BIDS, 'directions', 'sub',subj{1}, 'ses',SESS{sessInd}, 'modality','fmap', 'suffix','epi');
                uniqeDirs = {};
                while ~isempty(DIRs)
                    uniqeDirs(end+1) = DIRs(1); DIRs(1) = [];
                    DIRs(strcmp(DIRs,fliplr(uniqeDirs{end}))) = [];
                end
                for pedir = uniqeDirs
                    for fmap = reshape(bids.query(BIDS, 'data', 'sub',subj{1}, 'ses',SESS{sessInd}, 'modality','fmap', 'suffix','epi', 'dir', pedir{1}),1,[])
                        images = cellstr(spm_select('FPList',spm_file(fmap{1},'path'),strrep(spm_file(fmap{1},'filename'),['dir-' pedir{1}],['dir-[' pedir{1} ']{2}'])));
                        hdr = jsonread(strrep(images{1},'.nii.gz','.json'));
                        hdr2 = jsonread(strrep(images{2},'.nii.gz','.json'));
                        hdr.PhaseEncodingDirection = {hdr.PhaseEncodingDirection hdr2.PhaseEncodingDirection};
                        if ~isfield(hdr,'IntendedFor')
                            logging.warning('No task specification found for fieldmap  %s -> assuming all run',images{1});
                            runName = '*';
                        else
                            switch spm_file(spm_file(hdr.IntendedFor,'path'),'basename')
                                case 'func'
                                    runName = regexp(hdr.IntendedFor,'(?<=task-)[^_]*','match','once');
                                    if ~isempty(runName)
                                        runNum = regexp(hdr.IntendedFor,'(?<=run-)[^_]*','match','once');
                                        if ~isempty(runNum), runName = [runName '-' runNum]; end
                                    else
                                        logging.warning('No task specification found for fieldmap  %s -> assuming all run',images{1});
                                        runName = '*';
                                    end
                                    runName = ['fmrirun-' runName];
                                case 'dwi'
                                    logging.warning('Fieldmap %s detected for diffusion -> assuming all run',images{1});
                                    runName = 'diffusionrun-*';
                            end
                        end

                        rapFmap.fname = images;
                        rapFmap.hdr = hdr;
                        rapFmap.run = runName;

                        if BIDSsettings.combinemultiple
                            rapFmap.run = [rapFmap.run '_' SESS{sessInd}];
                            fieldmapimages = horzcat(fieldmapimages,rapFmap);
                        else
                            fieldmapimages{sessInd} = horzcat(fieldmapimages{sessInd},rapFmap);
                        end
                    end
                end
            end
        end
    end

    if BIDSsettings.combinemultiple
        rap = addSubject(rap,subj{1},...
            'name',subj{1},...
            'structural',structuralimages,...
            'fmri',fmriimages,...
            'fieldmaps',fieldmapimages,...
            'diffusion',diffusionimages,...
            'specialseries',specialimages);
    else
        for sessInd = 1:numel(SESS)
            subjname = subj{1};
            if ~isempty(SESS{sessInd}), subjname = [subjname '_' SESS{sessInd}]; end

            rap = addSubject(rap,subj{1},...
                'name',subjname,...
                'structural',structuralimages{sessInd},...
                'fmri',fmriimages{sessInd},...
                'fieldmaps',fieldmapimages{sessInd},...
                'diffusion',diffusionimages{sessInd},...
                'specialseries',specialimages{sessInd});
        end
    end
end

%% Clean
if exist('tbSPM','var'), tbSPM.unload(); end

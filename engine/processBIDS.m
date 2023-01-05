function rap = processBIDS(rap,varargin)
% https://github.com/bids-standard/bids-matlab
% https://github.com/automaticanalysis/automaticanalysis/blob/0969fe35f6c355b35ccb76d68f77df1e02f93ab7/aa_engine/aas_processBIDS.m

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
%               - one cell is a selection for one "firstlevelmodel" (in the tasklist)
%               - tasks/runs selected for any "firstlevelmodel" are pre-processed
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
%     - 'omitNullEvents':
%           do not add "null" events to model (default = false)
%     - 'convertEventsToUppercase':
%           convert event names to uppercase as required for contrast specification based on
%           event names (default = false)
%     - 'maxEventNameLength:'
%           truncate event names longer than the specified value (default = inf)
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
BIDSsettings.combinemultiple = rap.acqdetails.input.combinemultiple;

argParse = inputParser;
argParse.addParameter('omitModeling',false,@(x) islogical(x) || isnumeric(x));
argParse.addParameter('regcolumn','trial_type',@ischar);
argParse.addParameter('stripEventNames',false,@(x) islogical(x) || isnumeric(x));
argParse.addParameter('omitNullEvents',false,@(x) islogical(x) || isnumeric(x));
argParse.addParameter('convertEventsToUppercase',false,@(x) islogical(x) || isnumeric(x));
argParse.addParameter('maxEventNameLength',inf,@isnumeric);
argParse.parse(varargin{:});

BIDSsettings.modelling = argParse.Results;

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
if isfield(rap.tasksettings,'firstlevelmodel')
    for m = 1:numel(rap.tasksettings.firstlevelmodel)
        rap.tasksettings.firstlevelmodel(m).xBF.UNITS  ='secs';
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

MOD = bids.query(BIDS, 'modalities');

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
    for sfx = intersect(strsplit(rap.tasksettings.fromnifti_structural.sfxformodality,':'), bids.query(BIDS, 'suffixes', 'modality', 'anat'),'stable')
        for sessInd = 1:numel(SESS)
            image = bids.query(BIDS, 'data', 'sub',subj{1}, 'sess',SESS{sessInd}, 'suffix',sfx{1});
            hdr = bids.query(BIDS, 'metadata', 'sub',subj{1}, 'sess',SESS{sessInd}, 'suffix',sfx{1});
            if isempty(fieldnames(hdr)), hdr = [];
            else, hdr = repmat({hdr},1,numel(image));
            end
            if BIDSsettings.combinemultiple
                structuralimages = horzcat(structuralimages,struct('fname',image,'hdr',hdr));
            else
                structuralimages{sessInd} = horzcat(structuralimages{sessInd},struct('fname',image,'hdr',hdr));
            end
        end
    end

    % fmri
    for task = bids.query(BIDS, 'tasks')
        for sessInd = 1:numel(SESS)
            RUNS = bids.query(BIDS, 'runs', 'sess', SESS{sessInd}, 'task', task{1}); if isempty(RUNS), RUNS = {''}; end

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
                if ~isempty(rap.acqdetails.selectedrun) && ~any(strcmp({rap.acqdetails.fmrirun(rap.acqdetails.selectedrun).name},taskname)), continue; end

                rap = addRun(rap, 'fmri', taskname);

                image = bids.query(BIDS, 'data', 'sub', subj{1}, 'sess',SESS{sessInd}, 'suffix', 'bold', 'task', task{1});
                hdr = bids.query(BIDS, 'metadata', 'sub', subj{1}, 'sess',SESS{sessInd}, 'suffix', 'bold', 'task', task{1}); if isempty(fieldnames(hdr)), hdr = []; end
                eventfile = bids.query(BIDS, 'data', 'sub', subj{1}, 'sess',SESS{sessInd}, 'suffix', 'events', 'task', task{1});

                if BIDSsettings.combinemultiple
                    fmriimages = horzcat(fmriimages,struct('fname',image,'hdr',hdr));
                else
                    fmriimages{sessInd} = horzcat(fmriimages{sessInd},struct('fname',image,'hdr',hdr));
                end

                TR = 0;
                if isfield(hdr,'RepetitionTime'), TR = hdr.RepetitionTime; end
            end
        end
    end

    if BIDSsettings.combinemultiple
        rap = addSubject(rap,'',...
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

            rap = addSubject(rap,'',...
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

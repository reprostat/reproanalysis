function rap = processBIDS(rap,varargin)
% https://github.com/bids-standard/bids-matlab
% https://github.com/automaticanalysis/automaticanalysis/blob/0969fe35f6c355b35ccb76d68f77df1e02f93ab7/aa_engine/aas_processBIDS.m

% Allow specify Subjects, Sessions and Events from Brain Imaging Data Structure (BIDS)
%
%       rap = aas_processBIDS(rap,[[<Name>,<Value>][,<Name>,<Value>]...])
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
%           selection of a subset of tasks/runs based on their names (e.g. 'task-001_run01')
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
%     - 'omitModeling':
%           return w/o processing modeling data (default = false)
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
argParse.addParameter('regcolumn','trial_type',@ischar);
argParse.addParameter('stripEventNames',false,@(x) islogical(x) || isnumeric(x));
argParse.addParameter('omitNullEvents',false,@(x) islogical(x) || isnumeric(x));
argParse.addParameter('convertEventsToUppercase',false,@(x) islogical(x) || isnumeric(x));
argParse.addParameter('maxEventNameLength',inf,@isnumeric);
argParse.addParameter('omitModeling',false,@(x) islogical(x) || isnumeric(x));
argParse.parse(varargin{:});

BIDSsettings.modelling = argParse.Results;

if BIDSsettings.combinemultiple
    logging.warning('WARNING: You have selected combining multiple BIDS sessions!\n\tMake sure that you have also set rap.options.autoidentify* appropriately!\n\tN.B.: <runname> = <BIDS task/run name>_<BIDS session name>');
end

% ensure that models (if any) use seconds
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
if isempty(SUBJ), logging.error('no subjects found in directory %s', rap.directoryconventions.rawdatadir);

SESS = bids.query(BIDS, 'sessions');
if ~isempty(SESS) && ~isempty(rap.acqdetails.input.selectedsessions), SESS = intersect(SESS,rap.acqdetails.input.selectedsessions); end

MOD = bids.query(BIDS, 'modalities');

for subj = SUBJ
    structuralimages = {};
    functionalimages = {};
    fieldmapimages = {};
    diffusionimages = {};
    specialimages = {};

    if numel(SESS) <= 1
        % anat
        for sfx = intersect(strsplit(rap.tasksettings.fromnifti_structural.sfxformodality,':'), bids.query(BIDS, 'suffixes', 'modality', 'anat'),'stable')
            image = bids.query(BIDS, 'data', 'sub', subj{1}, 'suffix', sfx{1});
            hdr = bids.query(BIDS, 'metadata', 'sub', subj{1}, 'suffix', sfx{1}); if isempty(fieldnames(hdr)), hdr = []; end
            structuralimages = horzcat(structuralimages,struct('fname',image{1},'hdr',hdr));
        end
    else
    end
end

%% Clean
if exist('tbSPM','var'), tbSPM.unload(); end

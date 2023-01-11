function rap = addSubject(rap, varargin)
% Add subject/data to the analysis. It can be called multiple times to add more subjects and/or more data to a particular subject.
%
% FORMAT function rap = addSubject(rap, data)
% Process only autoidentified images. User will be a warned about the lack of series specification. Subject name, which is used as a reference in reproa
% (i.e. when calling addEvent, addContrasts, etc.), will be automatically defined based on rap.directoryconventions.subjectdirectoryformat (MUST be 0-2):
%   0   - based on predefined list stored in rap.directoryconventions.subjectdirectorynames
%   1   - based on the "data" (see below)
%   2   - based on the order of specification (S01, S02, etc.)
%
% rap           - rap structure with parameters and tasklist
% data          - subject foldername within database.
%                   - for MRI: a single entry according to rap.directoryconventions.subjectoutputformat
%                   - for MEEG: it is a cell array of two entries according to rap.directoryconventions.meegsubjectoutputformat (1st entry for MEEG data)
%                     and rap.directoryconventions.subjectoutputformat (2nd entry for MRI data). When omitting the MRI data, the 2nd entry is an empty array.
%
%
% FORMAT function rap = addSubject(___,'name',name)
% An explicit way to specify subject name manually, rap.directoryconventions.subjectdirectoryformat MUST be set to 3.
%
% name          - subject name as text string
%
%
% FORMAT function rap = addSubject(___,'fmri',series)
% Specify functional MRI data.
%
% series        - for DICOM: array of series number(s) of EPIs. E.g.:
%                   two series of single-echo EPI: [5 10]
%                   two series of single-echo EPI and one series of multi-echo EPI with 5 echos: {5 10 15:19}
%               - for NIfTI: cell array containing one or more
%                   for structural: string containing a full or relative path (from the subject's dir)
%                   for 4D NIfTI: string containing a full or relative path (from the subject's dir)
%                   for whole-brain EPI: string containing a full or relative path (from the subject's dir). Can be specified only after fMRI series.
%                   for 3D NIfTI: cell array (i.e. nested) of strings of full path
%                 Strings can be replaced by structures with fields 'fname' (path to image) and 'hdr' (header structure or path to header) to specify metadata.
% Series have to be specified in the same order as the corresponding sessions have been added in the UMS. Missing series can be specified either with "0" (for numerical array input) or with "[]" (for cell array input).
%
%
% FORMAT function rap = addSubject(___,'meeg',series)
% Specify M/EEG data.
%
% series        - for MEEG: cell array of string containing a full or relative path (from the subject's dir)
%               Strings can be replaced by structures with fields 'fname' (path to image) and 'hdr' (header structure or path to header) to specify metadata.
% Series have to be specified in the same order as the corresponding sessions have been added in the UMS. Missing series can be specified either with "0" (for numerical array input) or with "[]" (for cell array input).
%
%
% FORMAT function rap = addSubject(___,'diffusion',series)
% Specify diffusion-weighted MRI data.
%
% series        - for DICOM: numeric array of series number(s)
%               - for NIfTI: cell of structure(s) with fields 'fname' (path to image), and 'bval', 'bvec'(path to bvals and bvecs)
% Series have to be specified in the same order as the corresponding sessions have been added in the UMS.
%
%
% FORMAT function rap = addSubject(___,'structural', series)
% Specify structural data (overwrites autoidentification).
%
% series        - for DICOM: numeric array of series number
%               - for NIfTI: cell containing a string (path to image) or a structure with fields 'fname' (path to image) and 'hdr' (header structure or path to header)
%
%
% FORMAT function rap = addSubject(___,'fieldmaps', series)
% Specify fieldmap data (overwrites autoidentification).
%
% series        - for DICOM: numeric array of series numbers
%               - for NIfTI: cell of structure with fields 'fname' (cell of 3 filenames - 2x magnitude + 1x phase), 'hdr' (header structure or path to header), and 'session' (cell of session names or '*' for all sessions)
%
%
% FORMAT function rap = addSubject(___,'specialseries', series)
% Specify 'special' data (e.g. ASL, MTI, MPM).
%
% series        - for DICOM: cell array of numeric arrays of series numbers
%               - for NIfTI: not supported yet
% Series have to be specified in the same order as the corresponding sessions have been added in the UMS.
%
%
% FORMAT function rap = addSubject(___,'ignoreseries', series)
% Specify DICOM series to be ignored during autoidentification.
%
% series        - numeric arrays of series numbers

%% Parse
iMRIData = 1; % new subject
iMEEGData = 1;
if isempty(rap.acqdetails.subjects(end).subjname)
    subjind = 1;
else
    subjind = numel(rap.acqdetails.subjects) + 1;
end

name = '';
switch rap.directoryconventions.subjectdirectoryformat
    case 0 % from predefined list
        name = rap.directoryconventions.subjectdirectorynames{subjind};
        data = varargin{1};
        varargin(1)= [];
    case 1 % from data
        data = varargin{1};
        varargin(1)= [];
    case 2 % S#
        name = sprintf('S%02d',subjind);
        data = varargin{1};
        varargin(1)= [];
    case 3 % manual
        data = varargin{1};
        varargin(1)= [];
    otherwise
        logging.error('Unknown subject directory format (rap.directoryconventions.subjectdirectoryformat=%d. Value only 0-3 is allowed.',rap.directoryconventions.subjectdirectoryformat);
end

argParse = inputParser;
argParse.addParameter('name','',@ischar);
argParse.addParameter('structural',[],@(x) isnumeric(x) || iscell(x));
argParse.addParameter('fmri',[],@(x) isnumeric(x) || iscell(x));
argParse.addParameter('meeg',{},@iscell);
argParse.addParameter('diffusion',[],@(x) isnumeric(x) || iscell(x));
argParse.addParameter('fieldmaps',[],@(x) isnumeric(x) || iscell(x));
argParse.addParameter('specialseries',[],@(x) isnumeric(x) || iscell(x));
argParse.addParameter('ignoreseries',[],@isnumeric);

try
    argParse.parse(varargin{:});
catch
    help(mfilename);
    logging.error('incorrect arguments');
end
args = argParse.Results;

%% Initialize subject
% with a blank template for a subject entry
fields=fieldnames(rap.acqdetails.subjects);
fields(strcmp(fields,'ATTRIBUTE')) = [];
for field=fields'
    thissubj.(field{1})={[]};
end
fields(strcmp(fields,'subjname')) = [];

% search for existing subject
name = args.name;
if ~isempty(name) && ~isempty(rap.acqdetails.subjects(1).subjname)
% name specified --> check whether subject already exists (only if there is at least one already)
    subjserach = strcmp({rap.acqdetails.subjects.subjname},name);
    if subjserach
        subjind = subjserach;
        thissubj = rap.acqdetails.subjects(subjind);
        iMRIData = numel(thissubj.mridata)+1;
        if isfield(thissubj,'meegdata'), iMEEGData = numel(thissubj.meegdata)+1; end
        for field=fields'
            thissubj.(field{1}){end+1}=[];
        end
    end
end

%% Data
try
    if iscell(data) && numel(data) == 2 % MEEG
        thissubj.meegdata{iMEEGData}=data{1};
        thissubj.mridata{iMRIData}=data{2};
        if isempty(name), name = getData(rap.directoryconventions.meegsubjectoutputformat,thissubj.meegdata{1}); end
    else % MRI
        thissubj.mridata{iMRIData}=data;
        if isempty(name), name = getData(rap.directoryconventions.subjectoutputformat,thissubj.mridata{1}); end
    end
catch
    logging.error('In addSubject, data is expected to be either single item, according to rap.directoryconventions.subjectoutputformat for MRI,\n\tor a cell of two items, according to rap.directoryconventions.subjectoutputformat and according to rap.directoryconventions.meegsubjectoutputformat for MEEG, written like this {''meegdata'',''mridata''}.');
end
thissubj.subjname = name;

%% Series
if ~isempty(args.fmri)
    if isnumeric(args.fmri) || isnumeric(args.fmri{1}) % DICOM series number
        thissubj.fmriseries{iMRIData}=args.fmri;
    else
        fMRI = {};
        fMRIdim = [];
        for s = 1:numel(args.fmri)
            if iscell(args.fmri{s}) % multiple 3D files
                fMRI{end+1} = args.fmri{s};
            elseif isempty(args.fmri{s}) % missing series
                fMRI{end+1} = [];
            elseif ischar(args.fmri{s}) ||... % NIfTI file
                    isstruct(args.fmri{s})    % hdr+fname
                % Get filename
                if isstruct(args.fmri{s})
                    if numel(args.fmri{s}.fname) > 1 % multiple 3D files
                        fMRI{end+1} = args.fmri{s};
                        continue;
                    end
                    fname = args.fmri{s}.fname;
                else
                    fname = args.fmri{s};
                end

                % - try in rawdatadir/mridata
                if ~exist(fname,'file'), fname = fullfile(findData(rap,'mri',thissubj.mridata{iMRIData}),fname); end
                if ~exist(fname,'file'), logging.error('File %s does not exist!',fname); end

                V = spm_vol(fname);
                if numel(V) > 1 % 4D --> fMRI
                    fMRI{end+1} = args.fmri{s};
                    fMRIdim(end+1,:) = V(1).dim(1:2); % collect inplane resolution
                else % 3D --> wholebrainepi ? structural
                    if ~isempty(fMRIdim) && any(all(fMRIdim == V.dim(1:2),2)) % same inplane resolution as any of the fMRIs
                        thissubj.wholebrainepi{iMRIData}=args.fmri(s);
                    else
                        thissubj.structural{iMRIData}=args.fmri(s);
                    end
                end
            else % mixed: DICOM series number for fMRI
                thissubj.fmriseries{iMRIData}=args.fmri{s};
            end
        end
        if ~isempty(fMRI) && any(cellfun(@(x) ~isempty(x), fMRI))
            thissubj.fmriseries{iMRIData}=fMRI;
        end
    end
end

if ~isempty(args.meeg)
    MEEG = {};
    for s = 1:numel(args.meeg)
        if isempty(args.meeg{s}) % missing series
            MEEG{end+1} = [];
        elseif ischar(args.meeg{s}) ||... % file
                isstruct(args.meeg{s})    % hdr+fname
            % Get filename
            if isstruct(args.meeg{s})
                fname = args.meeg{s}.fname;
            else
                fname = args.meeg{s};
            end

            % - try in rawmeegdatadir/meegdata
            if ~exist(fname,'file'), fname = fullfile(findData(rap,'meeg',thissubj.meegdata{iMEEGData}),fname); end
            % - try in rawmeegdatadir (for emptyroom)
            if ~exist(fname,'file'), fname = findData(rap,'meeg',fname); end
            if ~exist(fname,'file'), logging.error('File %s does not exist!',fname); end

            MEEG{end+1} = args.meeg{s};
        end
    end
    if ~isempty(MEEG) && any(cellfun(@(x) ~isempty(x), MEEG))
        thissubj.meegseriesnumbers{iMEEGData}=MEEG;
    end
end

if ~isempty(args.diffusion)
    thissubj.diffusionseries{iMRIData}=args.diffusion;
end

for meas = {'structural' 'fieldmaps' 'specialseries' 'ignoreseries'}
    if ~isempty(args.(meas{1})), thissubj.(meas{1}){iMRIData}=args.(meas{1}); end
end

% And put into acqdetails, replacing a single blank entry if it exists
rap.acqdetails.subjects(subjind)=thissubj;
end

function name = getData(format,data)
name = sprintf(format,data);
name = strtok(name,' */\\_,.');
end

% -*- texinfo -*-
% @deftypefn {Function} downloadData (@var{rap}, @var{dataset_id})
% @deftypefnx {Function} downloadData (@var{rap}, @var{dataset_id}, @var{subset})
% Download one of the predefined datasets into rap.directory_conventions.raw(meeg)datadir.
%
% Only does the download if rap.directory_conventions.raw(eeg)datadir does not yet exist or is empty.
%
% Inputs:
%   @itemize @bullet
%   @item
%   @var{rap}: The repro analysis parameter structure
%   @item
%   @var{dataset_id}: One of the following values
%     @itemize @bullet
%     @item
%     'MoAEpilot'
%     @item
%     'ds000114'
%     @item
%     'ds002737'
%     @item
%     'LEMON_EEG'
%     @item
%     'LEMON_MRI'
%     @end itemize
%   @item
%   @var{subset}: You may want to specify subset because the whole dataset is large. It is a cell array of path within the dataset.
%   @end itemize
%
% @end deftypefn
function downloadData(rap, dataset_id, subset)

%% Inputs checking
demodir = rap.directoryconventions.rawdatadir;
% When used in aas_log messages, escape backward slashes from windows paths.
logsafe_path = strrep(demodir, '\', '\\');

% Check aap.directory_conventions.rawdatadir
sources = strsplit(demodir, pathsep);
if length(sources)>1
    % only want one rawdatadir for downloadData
    logging.error('For use with aa_downloadData, aap.directory_conventions.rawdatadir (%s) must specify exactly one directory.', logsafe_path);
end

% Check dataset_id
datasets = {};
for d = jsonread('datasets.json')'
    [~,indFields] = intersect(fieldnames(d),{'ID' 'URL' 'type'});
    par = struct2cell(d);
    datasets{end+1} = datasetClass(par{indFields});
end
IDs = cellfun(@(d) d.ID, datasets,'UniformOutput',false);
ID_ind = strcmp(dataset_id, IDs);
if sum(ID_ind) ~= 1
    IDs_str = strjoin(IDs,', ');
    logging.error('Expected exactly one match for input dataset_id (%s) in list of known datasets %s', dataset_id, IDs_str);
end
dataset = datasets{ID_ind};

%% Download if not already has data
if ~exist(fullfile(demodir),'dir') ... % Does not exist yet
        || length(dir(demodir))<3 % Directory is empty (only . and .. entries in dir listing)

    [mkdir_status, mkdir_msg] = mkdir(demodir); % Create if needed
    if ~mkdir_status, logging.error('Failed to create directory %s, due to: %s', logsafe_dir, mkdir_msg); end

    logging.info('INFO: downloading demo data to %s', logsafe_path);

    % Download and unpack the data to a temp dir first
    if nargin == 3, dataset.subset = subset; end
    dataset.download(demodir);
else
    logging.info('downloadData: Directory %s is already non-empty, skipping data download', logsafe_path);
end

end

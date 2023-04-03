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
function demoDir = downloadData(rap, dataset_id, subset)

%% Inputs checking
demoDir = rap.directoryconventions.rawdatadir;
% When used in aas_log messages, escape backward slashes from windows paths.
logsafeDemoDir = strrep(demoDir, '\', '\\');

% Check rap.directoryconventions.rawdatadir
demoDir = strsplit(demoDir, pathsep);
if numel(demoDir) > 1
    % only want one rawdatadir for downloadData
    demoDir = demoDir{1};
    logsafeDemoDir = strrep(demoDir, '\', '\\');
    logging.warning('Multiple directories are specified in rap.directoryconventions.rawdatadir.\n\%s will use the first: %s', mfilename, logsafeDemoDir);
else
    demoDir = demoDir{1};
    logsafeDemoDir = strrep(demoDir, '\', '\\');
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
if ~exist(demoDir,'dir') ... % Does not exist yet
        || numel(dir(demoDir))<3 % Directory is empty (only . and .. entries in dir listing)

    [~, mkdirMsg] = dirMake(demoDir); % Create if needed
    if ~exist(demoDir, 'dir'), logging.error('Failed to create directory %s, due to: %s', logsafeDemoDir, mkdirMsg); end

    logging.info('downloadData:downloading demo data to %s', logsafeDemoDir);

    % Download and unpack the data to a temp dir first
    if nargin == 3, dataset.subset = subset; end
    dataset.download(demoDir);
else
    logging.info('downloadData:Directory %s is already non-empty, skipping data download', logsafeDemoDir);
end

end

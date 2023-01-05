% volunteer locator
%   mandatory inputs
%       rap
%       modality ('mri' or 'meeg')
%       subjpath (to locate)
%   optional inputs
%       dateData - return only data of specific date
%       getFullPath - return fullpath
%       isProbe - return empty if none found and do not throw error
%
% E.g.: 90952 --> CBU090952_MR09032/20090828_131456

function strSubj = findvol(rap,varargin)

DTFORMAT = {'yymmdd' 'yyyymmdd' 'yyyymmdd_HHMMSS'};

argParse = inputParser;
argParse.addRequired('modality',@(x) ismember(x, {'mri' 'meeg'}))
argParse.addRequired('subjpath',@ischar)
argParse.addOptional('dateData','',@ischar)
argParse.addOptional('getFullPath',false,@(x) islogical(x) || isnumeric(x))
argParse.addOptional('isProbe',false,@(x) islogical(x) || isnumeric(x))
argParse.parse(varargin{:});

subjpath = argParse.Results.subjpath;
fdate = argParse.Results.dateData;

switch argParse.Results.modality
    case 'mri'
        rawdatadir = rap.directoryconventions.rawdatadir;
        fFormat = 'subjectoutputformat';
    case 'meeg'
        rawdatadir = rap.directoryconventions.rawmeegdatadir;
        fFormat = 'meegsubjectoutputformat';
end

% Parse pathsep separated list
SEARCHPATH = strsplit(rawdatadir,pathsep);

% get subjname
if ~isempty(regexp(rap.directoryconventions.(fFormat),'%s', 'once')) % string input expected
    if ~ischar(subjpath)
        logging.error('Second input must be a string. Check rap.directoryconventions.%s', fFormat);
    end
else  % numeric input expected
    if ~isnumeric(subjpath)
        logging.error('Second input must be an integer. Check rap.directoryconventions.%s', fFormat);
    end
end
subjpath = sprintf(rap.directoryconventions.(fFormat),subjpath);

isFound = false;
for i = 1:numel(SEARCHPATH)
    if ~isempty(dir(fullfile(SEARCHPATH{i},subjpath)))
        isFound = true;
        break;
    end
end

if ~isFound
    if argParse.Results.isProbe, logging.warning('Subject %s* not found',subjpath);
    else, logging.error('Subject %s* not found',subjpath);
    end
    strSubj = '';
    return;
end

strSubj = SEARCHPATH(i);
for spath = strsplit(subjpath,filesep)
    strSubj = cellfun(@(s) cellstr(spm_select('FPList',s,'dir',spath{1})), strSubj, 'UniformOutput', false);
    strSubj = cat(1,strSubj{:});
end
if numel(strSubj) == 1 % exact match
    strSubj = strrep(strSubj{1},[SEARCHPATH{i} filesep],'');
else % pattern
    strSubj = strrep(strSubj{end},[SEARCHPATH{i} filesep],''); % in case of multiple entries
end

% regexp to find files/folders that start with alphanumeric characters (ignore . files)
strSubjDir = spm_select('List',fullfile(SEARCHPATH{i},strSubj),'dir','^[a-zA-Z0-9]*');
% if there is no subdirectory
if isempty(strSubjDir), strSubjDir = spm_select('List',fullfile(SEARCHPATH{i},strSubj),'^[a-zA-Z0-9]*'); end
if isempty(strSubjDir)
    if argParse.Results.isProbe, logging.warning('nothing found for path %s', fullfile(SEARCHPATH{i},strSubj));
    else, logging.error('nothing found for path %s', fullfile(SEARCHPATH{i},strSubj));
    end
    strSubj = '';
    return;
end

% handle CBU-style sub-directories with date formats
strSubjDir = cellstr(strSubjDir);
des = cellfun(@(x) datenum_which(x,DTFORMAT),strSubjDir);

if ~any(des)
    if ~isempty(fdate) % subfolder of specific date required
        if argParse.Results.isProbe, logging.warning('Subject %s* on date %s not found',subjpath,fdate);
        else, logging.error('Subject %s* on date %s not found',subjpath,fdate);
        end
        strSubj = '';
        return;
    else % no sub-folder required
        subfolder = '';
    end
else
    if ~isempty(fdate) % subfolder of specific date required
        testDir = strSubjDir(logical(des));
        [~,idf] = datenum_which(testDir{1},DTFORMAT);
        ind = find(des == datenum(fdate,DTFORMAT{idf}),1,'first'); % first matching subfolder (we do not even expect more)
        if isempty(ind)
            if argParse.Results.isProbe, logging.warning('Subject %s* on date %s not found',subjpath,fdate);
            else, logging.error('Subject %s* on date %s not found',subjpath,fdate);
            end
            strSubj = '';
            return;
        else
            subfolder = strSubjDir{ind};
        end
    else % no sub-folder required
        strSubjDir = strSubjDir(logical(des));
        subfolder = strSubjDir{1}; % first subfolder (if there is more, they are ignored)
    end
end


if argParse.Results.getFullPath
    strSubj = fullfile(SEARCHPATH{i},strSubj,subfolder);
else
    strSubj = fullfile(strSubj,subfolder);
end
end

function [de,  i] = datenum_which(datestr,dtformats)
isFound = false; de = 0;
for i = 1:numel(dtformats)
    if numel(datestr) ~= numel(dtformats{i}), continue; end
    try
        de = datenum(datestr,dtformats{i});
        isFound = true;
        break;
    catch
    end
end
if ~isFound, i = 0; end
end

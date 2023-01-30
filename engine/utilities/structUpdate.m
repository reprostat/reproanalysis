function sOut = structUpdate(varargin)

argParse = inputParser;
argParse.addRequired('sIn',@isstruct);
argParse.addRequired('sUpd',@isstruct);
argParse.addParameter('Mode','',@(x) ischar(x) & any(strcmp({'update','extend',''},x)));
argParse.addParameter('ignoreEmpty',false,@(x) islogical(x) | isnumeric(x));
argParse.parse(varargin{:});
sIn = argParse.Results.sIn;
sUpd = argParse.Results.sUpd;

if argParse.Results.ignoreEmpty
    fields = fieldnames(sUpd);
    isEmpty = cellfun(@(f) isempty(sUpd.(f)), fields);
    sUpd = rmfield(sUpd,fields(isEmpty));
end

% Nested structs
fields = fieldnames(sIn);
isStructField = cellfun(@(f) isstruct(sIn.(f)) & isfield(sUpd, f), fields);
for field = fields(isStructField)'
    sIn.(field{1}) = structUpdate(sIn.(field{1}),sUpd.(field{1}),'Mode',argParse.Results.Mode);
    sUpd.(field{1}) = sIn.(field{1});
end

% Update
switch argParse.Results.Mode
    case 'update'
        % remove common fields from input
        sOut = rmfield(sIn, intersect(fieldnames(sIn), fieldnames(sUpd)));
        % remove missing fields from update
        sUpd = rmfield(sUpd, setdiff(fieldnames(sUpd), fieldnames(sIn)));
    case 'extend'
        sOut = sIn;
        % remove common fields from update
        sUpd = rmfield(sUpd, intersect(fieldnames(sUpd), fieldnames(sIn)));
    otherwise % update and extend
        % remove common fields from input
        sOut = rmfield(sIn, intersect(fieldnames(sIn), fieldnames(sUpd)));
end

% Merge structs
sOut = cell2struct(...
    [struct2cell(sOut); struct2cell(sUpd)],...
    [fieldnames(sOut); fieldnames(sUpd)],...
    1);

% Initialisation module - check rap has been correctly set up by user
% Uses a copy of the parameters made taken straight after the recipe construction
% If rap structure is different, mistyping has probably occurred and an error will be generated

function rap = checkparameters(rap,task)
switch task
    case 'doit'
        % Check parameters
        validateParameters('rap',rmfield(rap,{'internal' 'tasklist' 'tasksettings'}),readxml(rap.internal.parametersetFile));

        % Check tasksettings
        for t = fieldnames(rap.tasksettings)'
            for ind = 1:numel(rap.tasksettings.(t{1}))
                sel = strcmp({rap.tasklist.main.name},t{1}) & ([rap.tasklist.main.index] == ind);
                switch sum(sel)
                    case 0
                        logging.error('No task %s with index %d found in the tasklist',t{1},ind);
                    case 1
                        task = rap.tasklist.main(sel);
                        if ~isempty(task.aliasfor), xml = readxml(spm_file(task.aliasfor,'ext','.xml'));
                        else, xml = readxml(spm_file(task.name,'ext','.xml'));
                        end
                        validateParameters(sprintf('rap.tasksettings.%s(%d)',t{1},ind),rap.tasksettings.(t{1})(ind),rmfield(xml.settings,intersect(fieldnames(xml.settings),{'COMMENT'})));
                    otherwise
                        logging.error('More than one task %s with index %d found in the tasklist',t{1},ind);
                end
            end
        end

    case 'checkrequirements'
end
end

function validateParameters(paramroot,parameters,schema)
    if isfield(schema,'ATTRIBUTE') && isfield(schema.ATTRIBUTE,'ignorecheck') && schema.ATTRIBUTE.ignorecheck, return; end % ignore parameter

    fieldsToCheck = intersect(fieldnames(parameters),fieldnames(schema));
    fieldsMissing = setdiff(fieldnames(schema),[fieldnames(parameters)' {'ATTRIBUTE' 'CONTENT'}],'stable'); % ignore ATTRIBUTE and CONTENT
    fieldsExtra = setdiff(fieldnames(parameters),fieldnames(schema),'stable');

    if ~isempty(fieldsMissing), logging.error(['Missing field(s) in ' paramroot ': ' strjoin(fieldsMissing,',')]); end
    if ~isempty(fieldsExtra), logging.error(['Extra field(s) in ' paramroot ': ' strjoin(fieldsExtra,',')]); end

    for f = reshape(fieldsToCheck,1,[])
        switch class(parameters.(f{1}))
            case 'struct'
                for s = parameters.(f{1})
                    validateParameters(strjoin([{paramroot} f],'.'),s,schema.(f{1}));
                end
            case 'char'
                if isfield(schema.(f{1}),'ATTRIBUTE') && isfield(schema.(f{1}).ATTRIBUTE,'ui') && ismember(schema.(f{1}).ATTRIBUTE.ui,{'dir', 'filename', 'dir_part', 'dir_list'})
                    checkPath(strjoin([{paramroot} f],'.'),parameters.(f{1}),'allowpathsep',strcmp(schema.(f{1}).ATTRIBUTE.ui,'dir_list'));
                end
        end
    end
end

% Assert that input path does not contain forbidden characters.
function checkPath(nme, pth, varargin)
    if isempty(pth), return; end

    argParse = inputParser;
    argParse.addParameter('allowpathsep',false,@(x) islogical(x) || isnumeric(x));
    argParse.addParameter('allowwildcards',false,@(x) islogical(x) || isnumeric(x));
    argParse.parse(varargin{:});
    checkPref = argParse.Results;

    % Save original pth input for use in log message
    % escape backward slashes from windows paths.
    logsafe_path = strrep(pth, '\', '\\');

    allowedchars = 'a-zA-Z_0-9-/.\_:';
    if checkPref.allowwildcards, allowedchars = [allowedchars, '*?']; end

    if ispc()
        % On windows:
        % - paths can start with a drive letter followed by a : when it is an absolute path
        % - paths natively have a \ as filesep (though can also have /)
        expression = ['([A-Z]:)?[\\', allowedchars, ']*'];
    else
        expression = ['[', allowedchars, ']*'];
    end

    if checkPref.allowpathsep, pths = strsplit(pth, pathsep);
    else, pths = {pth};
    end

    for currPath = pths
        matches = regexp(currPath{1}, expression, 'match');
        if numel(matches)~=1 || ~strcmp(matches{1},currPath{1})
            logging.error('Paths can only contain a-z, A-Z, 0-9, _, -, ., / and (in specific cases) wildcards/pathseps.\nYour path %s=''%s'' is not valid.',nme,logsafe_path);
        end
    end
end

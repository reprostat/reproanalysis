% Load parameter defaults and tasklist into the rap structure
%
% FORMAT rap = reproaWorkflow(tasklist)
% Parameter defaults are loaded from ~/.reproa/reproa_parameters_user.xml
%   - tasklist: XML-file containing the list of modules
%
% FORMAT rap = reproaWorkflow(parameters,tasklist)
%   - parameters: XML-file containing the parameter defaults
%   - tasklist: XML-file containing the list of modules
%
% Tibor Auer 2022

function rap = reproaWorkflow(varargin)
    global reproa
    assert(isa(reproa,'reproaClass'),'reproa is not initialised -> run reproaSetup')

    switch(numel(varargin))
        case 0
            warning('You must provide a tasklist to reproaWorkflow.\n');
        case 1
            parametersetFile = fullfile(reproa.configdir,reproa.parameterFile);
            tasklistFile = varargin{1};
        case 2
            parametersetFile = varargin{1};
            tasklistFile = varargin{2};
    end

    % Read parameterset
    rap = readParameterset(parametersetFile);

    % Read tasklist
    tasks = readParameterset(tasklistFile);

    % Process tasklist
    % - initialisation
    rap.tasklist.initialisation = [readModule('checkparameters.xml') readModule('evaluatesubjectnames.xml') readModule('initialiseanalysis.xml')];

    % - main
    rap.tasklist.main = rap.tasklist.initialisation(false);
    for m = reshape(tasks.module,1,[])
        if isfield(m,'aliasfor') && ~isempty(m.aliasfor)
            rap.tasklist.main(end+1) = readModule([m.aliasfor '.xml']);
            rap.tasklist.main(end).aliasfor = rap.tasklist.main(end).name;
            rap.tasklist.main(end).name = m.name;
        else
            rap.tasklist.main(end+1) = readModule([m.name '.xml']);
        end
        rap.tasklist.main(end).index = numel(strcmp({rap.tasklist.main.name},m.name));
        if isfield(rap.tasklist.main(end),'settings')
            rap.tasksettings.(m.name) = rap.tasklist.main(end).settings;
        end
    end
end

% This is used to set up particular components of the rap structure that
% change from module to module. It implements the ability to provide
% module-specific parameters (e.g., for branched workflows) by applying the
% values in extraparameters.rap to the rap structure after setting it up
%
% function rap = setCurrenttask(rap,varargin)
%  1. rap=setCurrenttask(rap) - resets rap to initial state as created by user script
%  2. rap=setCurrenttask(...,'task',indTask) - sets rap structure (e.g., root path) to correspond to kth task in the tasklist
%  3. rap=setCurrenttask(...,'updatedefaults',{'spm'}) - update tool defaults
%  4. rap=setCurrenttask(...,'subject',subj) - sets subject specific selected session

function [rap]=setCurrenttask(rap,varargin)

global reproacache;

argParse = inputParser;
argParse.addParameter('task',0,@isnumeric);
argParse.addParameter('updatedefaults',{'spm'},@(x) iscell(x) && all(cellfun(@(t) reproacache.isKey(['toolbox.' t]), x)));
argParse.addParameter('subject',0,@isnumeric);
argParse.parse(varargin{:});

% Reset rap
rap = structUpdate(rap,rap.internal.rap_initial,'Mode','update');
if isfield(rap.tasklist,'currenttask'), rap.tasklist = rmfield(rap.tasklist,'currenttask'); end

if argParse.Results.task
    indTask = argParse.Results.task;

    % load module
    if indTask < 0 % initialisation
        module = rap.tasklist.initialisation(-indTask);
        module.index = 1;
    else % main
        module = rap.tasklist.main(indTask);
    end

    if isfield(module.header,'modality')
        modality = module.header.modality;
        switch modality
            case 'MRI'
                modality = 'FMRI';
                runs = rap.acqdetails.fmriruns;
            case 'DWI'
                modality = 'FMRI';
                runs = rap.acqdetails.diffusionruns;
            case {'MTI' 'ASL'}
                modality = 'FMRI';
                runs = rap.acqdetails.specialruns;
            case {'MEEG' 'MEG' 'EEG'}
                modality = 'EEG';
                runs = rap.acqdetails.meegruns;
            otherwise
                modality = 'FMRI';
                runs = rap.acqdetails.fmriruns;
        end
    else
        logging.warning('WARNING:modality is not set; (F)MRI is assumed');
        modality = 'FMRI';
        runs = rap.acqdetails.fmriruns;
    end

    % Set SPM defaults appropriately
    if ismember(argParse.Results.updatedefaults,'spm')
        global defaults
        defaults.modality = modality;
    end

    % Locate m-file
    if exist(spm_file(module.name,'ext','.m'),'file'), funcname = module.name;
    elseif exist(spm_file(module.name,'ext','.xml'),'file')
        mod = readModule(spm_file(module.name,'ext','.xml'));
        if isfield(mod.header,'mfile'), funcname = mod.header.mfile; end
    elseif ~isempty(module.aliasfor)
        mod = readModule(spm_file(module.aliasfor,'ext','.xml'));
        if isfield(mod.header,'mfile'), funcname = mod.header.mfile; end
    else
        logging.error('could not find m-file for module %s',module.name);
    end

    % Collect task info
    rap.tasklist.currenttask.extraparameters =  module.extraparameters;
    if isfield(rap.tasksettings,module.name)
        rap.tasklist.currenttask.settings =     rap.tasksettings.(module.name)(module.index);
    end
    rap.tasklist.currenttask.inputstreams =     module.inputstreams;
    rap.tasklist.currenttask.outputstreams =    module.outputstreams;
    rap.tasklist.currenttask.name =             sprintf('%s_%05d',module.name,module.index);
    rap.tasklist.currenttask.description =      module.header.desc;
    rap.tasklist.currenttask.mfile =            funcname;
    rap.tasklist.currenttask.index =            module.index;
    rap.tasklist.currenttask.tasknumber =       indTask;
    if isfield(module,'branchid')
        rap.tasklist.currenttask.branchid =     module.branchid;
    end
    rap.tasklist.currenttask.domain =           module.header.domain;
    rap.tasklist.currenttask.modality =         modality;

    % Update rap based on extraparameters.rap for this task
    if isfield(module.extraparameters,'rap')
        rap = structUpdate(rap,module.extraparameters.rap,'Mode','update');
    end

    % Check the apparent study root is set appropriately
    rap.acqdetails.root = getPathByDomain(rap,'study',[],'task',indTask);
    % ..and for remote filesystem if we're using one
    remotefilesystem = rap.directoryconventions.remotefilesystem;
    if ~strcmp(remotefilesystem,'none')
        rap.acqdetails.(remotefilesystem).root = getPathByDomain(rap,'study',[],'remoteFilesystem',remotefilesystem,'task',indTask);
    end

    % Parse selected_sessions into indices if necessary
    rap = parseSelectedruns(rap,runs,argParse.Results.subject);
end

end



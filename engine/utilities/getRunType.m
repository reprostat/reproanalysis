function run = getRunType(rap)

%% Modality
modality = '';
if isfield(rap.tasklist.currenttask,'modality'), modality = rap.tasklist.currenttask.modality; end
if isempty(modality)
    try, modality = spm_get_defaults('modality');
    catch
    end
end

% if module has specific run domain
if isempty(modality)
    switch rap.tasklist.currenttask.domain
        case 'fmrirun'
            modality = 'FMRI';
        case 'diffusionrun'
            modality = 'DWI';
        case 'meegrun'
            modality = 'MEEG';
        case 'specialrun'
            modality = 'X';
        otherwise
            % ignore generic run
    end
end

% last resort --> try modulename
if isempty(modality)
    if strfind(rap.tasklist.currenttask.name,'_epi'), modality = 'FMRI'; end
    if strfind(rap.tasklist.currenttask.name,'_diffusion'), modality = 'DWI'; end
    if strfind(rap.tasklist.currenttask.name,'_MTI'), modality = 'X'; end
    if strfind(rap.tasklist.currenttask.name,'_ASL'), modality = 'X'; end
    if strfind(rap.tasklist.currenttask.name,'_meeg'), modality = 'MEEG'; end
end

% default
if isempty(modality)
%     logging.warning('modality cannot be determined; (F)MRI is assumed');
    modality = 'FMRI'; % default modality
end

%% Run
switch modality
    case 'FMRI'
        run = 'fmrirun';
    case 'DWI'
        run = 'diffusionrun';
    case 'MEEG'
        run = 'meegrun';
    case 'X'
        run = 'specialrun';
end
end

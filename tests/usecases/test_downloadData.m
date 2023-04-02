rap = reproaWorkflow('SPM_CH30.xml');
dataroot = rap.directoryconventions.rawdatadir;

%% MoAEpilot
rap.directoryconventions.rawdatadir = fullfile(dataroot, 'MoAEpilot');
downloadData(rap, 'MoAEpilot');

%% ds000114
rap.directoryconventions.rawdatadir = fullfile(dataroot, 'ds000114');
downloadData(rap, 'ds000114',  'sub-01');

%% ds002737
rap.directoryconventions.rawdatadir = fullfile(dataroot, 'ds000114');
downloadData(rap, 'ds002737',  'sub-01/ses-03');

%% LEMON_MRI
rap.directoryconventions.rawdatadir = fullfile(dataroot, 'ds000114');
downloadData(rap, 'LEMON_MRI',  'sub-032301/ses-01/anat');

%% LEMON_EEG
rap.directoryconventions.rawdatadir = fullfile(dataroot, 'ds000114');
downloadData(rap, 'LEMON_EEG',  'sub-032301');


rap = reproaWorkflow('SPM_CH30.xml');
dataroot = rap.directoryconventions.rawdatadir;

%% MoAEpilot
rap.directoryconventions.rawdatadir = fullfile(dataroot, 'MoAEpilot');
downloadData(rap, 'MoAEpilot');

%% ds000114
rap.directoryconventions.rawdatadir = fullfile(dataroot, 'ds000114');
downloadData(rap, 'ds000114',  'sub-01');

%% ds002737
rap.directoryconventions.rawdatadir = fullfile(dataroot, 'ds002737');
downloadData(rap, 'ds002737',  'sub-01/ses-03');

%% LEMON_MRI
rap.directoryconventions.rawdatadir = fullfile(dataroot, 'LEMON-MRI');
downloadData(rap, 'LEMON-MRI',  'sub-032301/ses-01/anat');

%% LEMON_EEG
rap.directoryconventions.rawdatadir = fullfile(dataroot, 'LEMON-EEG');
downloadData(rap, 'LEMON-EEG',  'sub-032301');

%% Report
global reproaworker
copyfile(reproaworker.logFile,fileparts(fileparts(mfilename('fullpath'))));
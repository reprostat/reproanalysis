% FILE: fmri_extended.m
%
% This script runs an extended fMRI analysis.
%
% It takes about 1-2 hours. depending on your computer.
%
% Make a copy of this file to edit and put it somewhere in your MATLAB/Octave
% path along with a copy of the task list fmri_extended.xml
%
% Variable names in ALLUPPERCASE are placeholders that you will need to
% customize before the script can be run.

% Data
%
% This script uses the OpenNeuro dataset ds000249, available at:
%
%  https://openneuro.org/datasets/ds000249
%
% Download and place the folder somewhere convenient on your machine.
% Alternatively, reproa will attempt to automatically download the data for you
% when the script runs (see comment at downloaddata below).

rap = reproaWorkflow('fmri_extended.xml');

rap.options.wheretoprocess = 'batch';

%DATA_PATH = '/fullpath/to/ds000249';
DATA_PATH = '/ceph/users/usq33871/data/ds000249';
rap.directoryconventions.rawdatadir = DATA_PATH;

%ROOT_PATH = '/path/to/dir/where/results_directory/will/be/created';
%rap.acqdetails.root = ROOT_PATH;
RESULTS_DIR = 'fmri_extended';
rap.directoryconventions.analysisid = RESULTS_DIR;

rap.acqdetails.input.combinemultiple = 0;
rap.acqdetails.input.correctEVfordummies = 0;

rap.tasksettings.reproa_fromnifti_fmri.numdummies = 0;

rap = renameStream(rap,'reproa_fieldmap2VDM_00001','input','fieldmap','dualtefieldmap');

rap = renameStream(rap,'reproa_realignunwarp_00001','input','weighting_image','fmri_sd');
rap.tasksettings.reproa_realignunwarp.invertweighting = 1;

rap.tasksettings.reproa_slicetiming.useheader = 1;
rap.tasksettings.reproa_slicetiming.refslice = 1;

rap.tasksettings.reproa_segment.normalisation.affreg = '';
rap.tasksettings.reproa_segment.writenormalised.method = 'none';
rap.tasksettings.reproa_dartelnormwrite_fmri.write.vox = [3 3 3];
rap.tasksettings.reproa_dartelnormwrite_fmri.fwhm = ...
    rap.tasksettings.reproa_dartelnormwrite_fmri.write.vox;
rap.tasksettings.reproa_smooth_fmri.FWHM = 6;

rap.tasksettings.reproa_firstlevelmodel.xBF.UNITS = 'secs';
rap.tasksettings.reproa_firstlevelmodel.includemovementparameters = [1 1 0; 1 1 0];

rap.tasksettings.reproa_firstlevelthreshold.threshold.correction = 'none';
rap.tasksettings.reproa_firstlevelthreshold.threshold.p = 0.001;
rap.tasksettings.reproa_firstlevelthreshold.threshold.extent = 'FWE:0.05';

rap = processBIDS(rap);

for m = [rap.tasksettings.reproa_firstlevelmodel.model]
    switch m.fmrirun
        case 'linebisection'
            rap = addContrast(rap, 'reproa_firstlevelcontrasts', '*', ['runs:' m.fmrirun], '+1*Correct_Task|-1*Incorrect_Task', 'CorrectVsIncorrect','T');
            rap = addContrast(rap, 'reproa_firstlevelcontrasts', '*', ['runs:' m.fmrirun], '+0.5*Correct_Task|+0.5*Incorrect_Task|-1*No_Response_Task', 'TaskResponse','T');
            rap = addContrast(rap, 'reproa_firstlevelcontrasts', '*', ['runs:' m.fmrirun], '+1*Response_Control|-1*No_Response_Control', 'ControlResponse','T');
        otherwise
            for e = {m(1).event.name}
                rap = addContrast(rap, 'reproa_firstlevelcontrasts', '*', ['runs:' m.fmrirun], ['+1*' e{1}], e{1},'T');
            end
    end
end

processWorkflow(rap);
reportWorkflow(rap);

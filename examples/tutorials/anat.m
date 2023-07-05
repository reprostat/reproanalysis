% FILE: anat.m
%
% This script runs the structural preprocessing using SPM.
%
% Make a copy of this file to edit and put it somewhere in your MATLAB/Octave
% path along with a copy of the task list anat.xml
%
% Variable names in ALLUPPERCASE are placeholders that you will need to
% customize before the script can be run.

% Data
%
% This script uses a single session of four subjects of the LEMON dataset
% (sub-032301/ses-01/anat, sub-032302/ses-01/anat, sub-032303/ses-01/anat, 
% sub-032304/ses-01/anat) available in BIDS at:
% 
% http://fcon_1000.projects.nitrc.org/indi/retro/MPI_LEMON.html.
%
% You can download and place the dataset somewhere convenient on your machine. 
% You do not have to download the whole data for the demo, just the
% ses-01/anat of the first four partiipants. Alternatively, reproa will attempt 
% to automatically download the data for you when the script runs (see comment 
% at downloaddata below).

% -------------------------------------------------------------------------
% 0) initialization
% -------------------------------------------------------------------------

% a call to reproaSetup is required as the first line of an reproa script
reproaSetup();

% -------------------------------------------------------------------------
% 1) initializing the Repro Analysis Parameter (rap) structure
% -------------------------------------------------------------------------
%
% A reproa script begins with a call to reproaworkflow to create an rap
% structure. This function takes a tasklist file and (optionally) a parameterset
% file. If no parameterset file is passed, the default parameterset file will be
% used, which is assumed to be:
%
%       $HOME/.reproa/reproa_parameters_user.xml
%
% This file must exist if a parameter file is not passed to reproaworkflow.
%
% To use a named parameter file (customised, say, for a specific analysis)
% pass a path to the file as the first parameter in reproaworkflow:
%
%   rap = reproaWorkflow('/path/to/parameterFile', /path/to/tasklistFile);
%

% Note we assued the tasklist is named "SPM_CH30.xml". It is common
% practice to keep this file in the same directory as the "userscript"
% (the file you are currently viewing) and having the the same name
% (albeit with an xml extension).
rap = reproaWorkflow('anat.xml');

% ------------------------------------------------------------------------
% 2) specify the data directory
% -------------------------------------------------------------------------
%
% reproa will look for data to be used in a given analysis in
%
%   rap.directoryconventions.rawdatadir
%
% when using BIDS data, this is simply the top level BIDS directory.
%
% If you downloaded the LEMON data, set DATAPATH to the fullpath
% name of where the data is located:
%
% for example: DATA_PATH = '/volumes/bigdisk/imaging/LEMON'
DATA_PATH = '/fullpath/to/LEMON';
rap.directoryconventions.rawdatadir = DATA_PATH;

% If you would like to have reproa attempt to automatically download the
% data for you, set autodownloadflag to true
autodownloadflag = false;

if (autodownloadflag == true)
    downloadData(rap, 'LEMON_MRI',{'sub-032301/ses-01/anat'...
                                   'sub-032302/ses-01/anat'...
                                   'sub-032303/ses-01/anat'...
                                   'sub-032304/ses-01/anat'});
end

% note that automatic data download occasionally fails due to
% network issues, server availablilty, etc)

% ------------------------------------------------------------------------
% 3) specify the results directory
% -------------------------------------------------------------------------
%
% reproa will save analysis results to the directory:
%
%   rap.acqdetails.root/rap.directoryconventions.analysisid
%
% rap will create rap.acqdetails.root/rap.directoryconventions.analysisid if
% not exists
%
% Some reproa users prefer to always use the default settings of these
% parameters (set in the parameter file). If you used the reproa parameter file
% utility, you specified these directories during setup). However, here we
% will explicity set these parameters for illustrative purposes (parameters
% set in the userscript override the value set in the parameter file).

% for example: ROOT_PATH = '/volumes/bigdisk/imaging'
%              RESULTS_dir = 'LEMON_MRI_RESULTS'

% (it is generally good practice to keep results separate from the data)
ROOT_PATH = '/path/to/dir/where/results_directory/will/be/created';
rap.acqdetails.root = ROOT_PATH;

RESULTS_DIR = 'name_of_results_directory';
rap.directoryconventions.analysisid = RESULTS_DIR;

% -------------------------------------------------------------------------
% 4) specify analysis options
% -------------------------------------------------------------------------

% here we demonstrate the bare minimum of customizing analysis settings

% note variables not set here will use default values specified either
% in your parameter file or taken from the module header (see any XML file in
% the "modules" directory of the reproa distribution for examples)

% Since the LEMON dataset has both T1w and T2w images, we MUST indicate it in 
% the data import module reproa_fromnifti_structural. It will also inform 
% processBIDS, so it will also look for (only) these modalities
rap.tasksettings.reproa_fromnifti_structural.sfxformodality = 'T1w:T2w';

% To improve segmantation and normalisation, the outputs (structural and t2)
% SHOULD be aligned with the MNI template.
rap.tasksettings.reproa_coregextended_t2.reorienttotemplate = 1;

% Since the normalistion will be performed with DARTEL, we do not need
% normalised output from SPM' Unified Segment/Normalise
rap.tasksettings.reproa_segment.writenormalised.method = 'none';

% A minimum smoothing is REQUIRED to mitigate the nonlinear transformation 
% artefacts. One can use this step to set the smoothness of the images to the
% desired level, in which case the last smoothing task SHOULD be removed.
% Running the smoothing seperately, however, allows to demonstrate the use of
% generic modules, such as reproa_smooth.
rap.tasksettings.reproa_dartelnormwrite_segmentations.fwhm = [1 1 1];

% Morphometry analysis MUST consider individual differences in head size. To
% avoid the need for extra regressors in the design, one can scale the
% segmentations instead. Using 'each' means the GM and WM estimates are scaled
% by total GM and WM volume, respectively. An alternative solution is to use TIV
% for both (scaleby = 'TIV').
rap.tasksettings.reproa_scale_segmentations.scaleby = 'each';
% Using the SPM estimate rather than directly calculating them from the 
% segmentation volumes is usually more robust.
rap.tasksettings.reproa_scale_segmentations.estimatefrom = 'spm';

% The final smoothness of the segmentations are set in this separate step. Since
% reproa_smooth is a generic module, its default input ('fmri') MUST be renamed.
rap = renameStream(rap,'reproa_smooth_00001','input','fmri','normaliseddensity_segmentations');
rap.tasksettings.reproa_smooth.FWHM = 8;

% -------------------------------------------------------------------------
% 5) process BIDS input
% -------------------------------------------------------------------------

rap = processBIDS(rap);

% -------------------------------------------------------------------------
% 6) run and report
% -------------------------------------------------------------------------

processWorkflow(rap);
reportWorkflow(rap);

% -------------------------------------------------------------------------
% 7) cleanup path and global variables
% -------------------------------------------------------------------------

reproaClose();

% done!

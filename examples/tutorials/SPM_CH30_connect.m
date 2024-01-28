% FILE: SPM_CH30_connect.m
%
% This script runs the GLM analysis of the Auditory fMRI example from the SPM
% manual (chapter 30, as of this writing).
%
% It takes about 5-10 min. depending on your computer.
%
% Make a copy of this file to edit and put it somewhere in your MATLAB/Octave
% path along with a copy of the task list SPM_CH30_connect.xml
%
% Variable names in ALLUPPERCASE are placeholders that you will need to
% customize before the script can be run.

% Data
%
% This script connects to the SPM_CH30 workflow to retrieve the preprocessed
% data. See SPM_CH30.m for further details.
%
% -------------------------------------------------------------------------
% 0) initialization
% -------------------------------------------------------------------------

% A call to reproaSetup is required as the first line of a reproa script.
% However, if you run it after SPM_CH30.m, the you can leave it out.
reproaSetup();

% -------------------------------------------------------------------------
% 1) initializing the Repro Analysis Parameter (rap) structure
% -------------------------------------------------------------------------

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

% Note we assued the tasklist is named "SPM_CH30_connect.xml". It is common
% practice to keep this file in the same directory as the "userscript"
% (the file you are currently viewing) and having the the same name
% (albeit with an xml extension).
rap = reproaWorkflow('SPM_CH30_connect.xml');

% ------------------------------------------------------------------------
% 2) specify and connect the remote workflow(s)
% -------------------------------------------------------------------------

% This script assumes that the example script SPM_CH30.m has been successfully
% executed. REMOTEPATH MUST point to the results directory containing rap.mat.
REMOTEPATH = '/path/to/the finished/SPM_CH30';
rap.acqdetails.input.remoteworkflow(1) = struct(...
   'host','',...
   'path',REMOTEPATH,...
   'allowcache',0,...
   'maxtask',''...
   );
rap = reproaConnect(rap,'subjects','*','runs','*');

% ------------------------------------------------------------------------
% 3) specify the results directory
% -------------------------------------------------------------------------

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
%              RESULTS_dir = 'MoAEpilot_RESULTS'

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

% UNITS can be 'secs' or 'scans' (the SPM auditory tutorial has it set
% for 'scans' in the manual but a BIDS tsv is always specified in secs)
rap.tasksettings.reproa_firstlevelmodel.xBF.UNITS = 'secs';

% Include realignement parameters extended to the first and second orders and derivatives
rap.tasksettings.reproa_firstlevelmodel.includemovementparameters = [1 1 0; 1 1 0];

% Set threshold uncorrected voxelwise p=0.001 (~Z=3.1) cluster-forming threshold
% with p=0.05 (FWE-corrected) cluster extent threshold
rap.tasksettings.reproa_firstlevelthreshold.threshold.correction = 'none';
rap.tasksettings.reproa_firstlevelthreshold.threshold.p = 0.001;
rap.tasksettings.reproa_firstlevelthreshold.threshold.extent = 'FWE:0.05';

% -------------------------------------------------------------------------
% 5) modeling - contrast specification
% -------------------------------------------------------------------------

rap = addEvent(rap, 'reproa_firstlevelmodel', '*', '*', 'listening', 42:84:546, 42);

% note any calls to addContrast MUST appear *after* processBIDS

rap = addContrast(rap, 'reproa_firstlevelcontrasts', '*', '*', 1, 'L_G_R','T');

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

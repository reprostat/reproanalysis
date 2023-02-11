% FILE: SPM_CH30.m
%
% This script runs the Auditory fMRI example from the SPM manual
% (chapter 30, as of this writing).
%
% Make a copy of this file to edit and put it somewhere in your MATLAB/Octave
% path along with a copy of the task list SPM_CH30.xml
%
% Variable names in ALLUPPERCASE are placeholders that you will need to
% customize before the script can be run.

% Data
%
% This script uses the BIDS version of the chapter 30 data, available at:
%
%  https://www.fil.ion.ucl.ac.uk/spm/download/data/MoAEpilot/MoAEpilot.bids.zip
%
% Download & unzip this file and place the folder somewhere convenient
% on your machine. Alternatively, reproa will attempt to automatically
% download the data for you when the script runs (see comment at downloaddata
% below).

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
rap = reproaWorkflow('SPM_CH30.xml');

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
% If you downloaded the MoAEpilot data, set DATAPATH to the fullpath
% name of where the data is located:
%
% for example: DATA_PATH = '/volumes/bigdisk/imaging/MoAEpilot'
DATA_PATH = '/fullpath/to/MoAEpilot';
rap.directoryconventions.rawdatadir = DATA_PATH;

% If you would like to have aa attempt to automatically download the
% data for you, set autodownloadflag to true
autodownloadflag = false;

if (autodownloadflag == true)
    downloadData(rap, 'MoAEpilot');
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

% the SPM manual describes removing inital volumes because of T1
% effects. However, these volumes have been omitted when the BIDS
% data was generated so adjustment is unnecessary here. Otherwise we would
% set numdummies > 0 and also set correctEVfordummies = 1 (true) so that
% event timing (read from the BIDS tsv files) would be corrected.
rap.tasksettings.fromnifti_fmri.numdummies = 0;
rap.acqdetails.input.correctEVfordummies = 0;

% OPTIONAL - Although the SPM manual does not contain, we can use the temopral
% SD of the run to weight realignment. SD images MUST be inverted
rap = renameStream(rap,'realign_00001','input','weighting_image','fmri_sd');
rap.tasksettings.realign.invertweighting = 1;

% Since the workflow includes initial registration of the structural image, we
% can leave it out during normalisation
rap.tasksettings.segment.normalisation.affreg = '';

% the SPM manual specifies a smoothing kernal of 6 mm. We can set this
% here in the rap struct.
rap.tasksettings.smooth.FWHM = 6;

% UNITS can be 'secs' or 'scans' (the SPM auditory tutorial has it set
% for 'scans' in the manual but a BIDS tsv is always specified in secs)
rap.tasksettings.firstlevelmodel.xBF.UNITS = 'secs';

% Include realignement parameters extended to the first and second orders and derivatives
rap.tasksettings.firstlevelmodel.includerealignmentparameters = [1 1 0; 1 1 0];

% -------------------------------------------------------------------------
% 5) process BIDS input
% -------------------------------------------------------------------------

rap = processBIDS(rap);

% -------------------------------------------------------------------------
% 6) modeling - contrast specification
% -------------------------------------------------------------------------

% processBIDS will define the events for the model (these are read from
% the events.tsv files in the BIDS directory), but you MUST define the contrasts
% that appear in your model using addContrast

% note any calls to addContrast MUST appear *after* processBIDS

rap = addContrast(rap, 'firstlevelcontrasts', '*', '*', 1, 'L_G_R','T');

% -------------------------------------------------------------------------
% 7) run and report
% -------------------------------------------------------------------------

processWorkflow(rap);
reportWorkflow(rap);

% -------------------------------------------------------------------------
% 8) cleanup path and global variables
% -------------------------------------------------------------------------

reproaClose();

% done!

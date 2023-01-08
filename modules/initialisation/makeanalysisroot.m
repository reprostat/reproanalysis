% Makes study directory

function rap = makeanalysisroot(rap,task)

switch task
    case 'doit'
        switch rap.directoryconventions.remotefilesystem
            case 'none'
                studyDir = rap.internal.rap_initial.acqdetails.root;
                if ~exist(studyDir,'dir'), dirMake(studyDir);
                elseif ~rap.directoryconventions.continueanalysis, logging.error('There is a file with the same name as the desired study directory: %s',studyDir);
                end
            otherwise
                logging.error('NYI');
        end
end





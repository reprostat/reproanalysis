function testRun(testScript,taskList,varargin)

    argParse = inputParser;
    argParse.addParameter('deletePrevious',false,@(x) islogical(x) || isnumeric(x));
    argParse.addParameter('whereToProcess','localsingle',@(x) ischar(x) && ismember(x, {'localsingle'}));
    argParse.parse(varargin{:});

    rap = reproaWorkflow([taskList '.xml']);

    testInfo = strsplit(testScript,'_');
    dataName = strjoin(testInfo(2:end-1),'_');

    rap.directoryconventions.rawdatadir = fullfile(rap.directoryconventions.rawdatadir, dataName);
    rap.directoryconventions.analysisid = testScript;

    downloadData(rap, dataName);

    analysisDir = fullfile(rap.acqdetails.root,rap.directoryconventions.analysisid);
    if argParse.Results.deletePrevious && exist(analysisDir,'dir')
        delete(analysisDir);
    end

    rap.options.wheretoprocess  = argParse.Results.whereToProcess;

    func = str2func(testScript);
    func(rap);

    global reproaworker
    copyfile(reproaworker.logFile,fileparts(mfilename('fullpath')));

    exportReport(analysisDir,spm_file(mfilename('fullpath'),'filename','report'));

end

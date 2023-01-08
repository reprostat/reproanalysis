function rap = runModule(rap,indTask,command,dataIndices,varargin)

    global reproaworker
    global reproacache

    argParse = inputParser;
    argParse.addParameter('reproaworker',reproaworker,@(x) isa(x,'workerClass'));
    argParse.addParameter('reproacache',reproacache,@(x) isa(x,'cacheClass'));
    argParse.parse(varargin{:});

    reproaworker = argParse.Results.reproaworker;
    reproacache = argParse.Results.reproacache;

    % load task
    rap = setCurrenttask(rap,'task',indTask);

    % run task
    rap = evalModule(rap.tasklist.currenttask.mfile,rap,command,dataIndices);
end

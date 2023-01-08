function rap = runModule(rap,indTask,command,indices,varargin)

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
    studyPath = spm_file(getPathByDomain(rap,'study',[]),'path');
    taskRoot = getPathByDomain(rap,rap.tasklist.currenttask.domain,indices);
    pDesc = strsplit(strrep(taskRoot,[studyPath filesep],''),filesep);
    if numel(pDesc)==1, pDesc{2} = 'study';
    else, pDesc{2} = strjoin(pDesc(2:end),'/');
    end

    % run task
    if indTask < 0 % initialisation
        logging.info('INITIALISATION - %s RUNNING: %s on %s',pDesc{1},rap.tasklist.currenttask.description,pDesc{2});
    else
        logging.error('NYI');
    end

    rap = evalModule(rap.tasklist.currenttask.mfile,rap,command,indices);
end

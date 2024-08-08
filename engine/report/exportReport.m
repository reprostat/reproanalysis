function exportReport(studyPath, target)

    mediaDir = fullfile(target,'media');

    dirMake(target);
    dirMake(mediaDir);

    load(fullfile(studyPath,'rap_reported.mat'),'rap');
    oldRoot = fullfile(rap.acqdetails.root,rap.directoryconventions.analysisid);

    copyfile(fullfile(studyPath,'rap_*'),target);
    for fn = reshape(rap.report.attachment,1,[])
        copyfile(strrep(fn{1},oldRoot,studyPath),mediaDir);
    end

    reportFields = fieldnames(rap.report);

    for repDir = reshape(reportFields(lookFor(fieldnames(rap.report),'Dir')),1,[])
        dirMake(fullfile(strrep(rap.report.(repDir{1}),oldRoot,target)));
    end

    % top-level HTMLs
    topHMLSs = {'main' 'sub0'};
    if ~isempty(rap.report.summaries), topHMLSs = [topHMLSs rap.report.summaries(:,1)']; end

    % HTMLs in subfolders
    subHTMLs = reportFields(lookFor(reportFields,'(con[1-9])|(sub[1-9])','regularExpression',true))';

    for html = [topHMLSs subHTMLs]
        switch html{1}
            case topHMLSs
                relTarget = '.';
                relMedia = './media/';
            case subHTMLs
                relTarget = '..';
                relMedia = '../media/';
        end

        content = strrep(fileread(strrep(rap.report.(html{1}).fname,oldRoot,studyPath)),'\','/');
        content = regexprep(content,['(?<=href=")' strrep(oldRoot,'\','/')],relTarget);
        content = regexprep(content,'(?<=src=")[a-zA-Z0-9-_:\\/]*(?=diagnostic)',relMedia);

        newFn = strrep(rap.report.(html{1}).fname,oldRoot,target);
        fid = fopen(newFn,'w');
        if fid == -1, logging.error('Failed to open %s',newFn); end
        fprintf(fid,'%s',content);
        fclose(fid);
    end
end

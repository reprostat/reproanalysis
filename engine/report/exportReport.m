function exportReport(studyPath, target)

    mediaDir = fullfile(target,'media');

    dirMake(target);
    dirMake(mediaDir);

    load(fullfile(studyPath,'rap_reported.mat'),'rap');
    oldRoot = fullfile(rap.acqdetails.root,rap.directoryconventions.analysisid);

    for fn = rap.report.attachment
        copyfile(fn,mediaDir);
    end

    reportFields = fieldnames(rap.report);

    for repDir = reshape(reportFields(contains(fieldnames(rap.report),'Dir')),1,[])
        dirMake(fullfile(strrep(rap.report.(repDir{1}),oldRoot,target)));
    end

    for html = setdiff(reportFields,{'style' 'attachment' 'conDir' 'fbase' 'subjDir' 'summaries' 'realign'})'
        content = strrep(fileread(rap.report.(html{1}).fname),'\','/');
        content = regexprep(content,['(?<=href=")' strrep(oldRoot,'\','/')],strrep(target,'\','/'));
        content = regexprep(content,'(?<=src=")[a-zA-Z0-9-_:\\/]*(?=diagnostic)',[strrep(mediaDir,'\','/') '/']);

        newFn = strrep(rap.report.(html{1}).fname,oldRoot,target);
        fid = fopen(newFn,'w');
        if fid == -1, logging.error('Failed to open %s',newFn); end
        fprintf(fid,'%s',content);
        fclose(fid);
    end
end

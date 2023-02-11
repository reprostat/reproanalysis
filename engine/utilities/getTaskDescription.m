function desc = getTaskDescription(rap,indices)
    studyPath = spm_file(getPathByDomain(rap,'study',[]),'path');
    taskRoot = getPathByDomain(rap,rap.tasklist.currenttask.domain,indices);
    pDesc = strsplit(strrep(taskRoot,[studyPath filesep],''),filesep);
    if numel(pDesc)==1, pDesc{2} = 'study';
    else, pDesc{2} = strjoin(pDesc(2:end),'/');
    end
    desc = sprintf('%s: %s on %s',pDesc{1},rap.tasklist.currenttask.description,pDesc{2});
end

% check if file exists, if yes, delete

function fileDelete(fname)
    if exist(fname,'file'), delete(fname); end
end

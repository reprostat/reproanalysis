function fname = webSave(fname,url,options)
    fid = fopen(fname,'w');
    fputs(fid,webread(url,options));
    fclose(fid);
    jf = javaObject('java.io.File',fname);
    if ~jf.isAbsolute(), fname = fullfile(pwd,fname); end
end


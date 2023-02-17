function fname = webSave(fname,url,options)
    if isOctave()
        fid = fopen(fname,'w');
        fputs(fid,webread(url,options));
        fclose(fid);
        jf = javaObject('java.io.File',fname);
        if ~jf.isAbsolute(), fname = fullfile(pwd,fname); end
    else
        websave(fname,url,options);
    end
end


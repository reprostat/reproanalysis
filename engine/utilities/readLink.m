function pth = readLink(pth)
    if isOctave()
        jvFile = javaObject('java.io.File',pth);
    else
        jvFile = java.io.File(pth);
    end

    pth = char(jvFile.getCanonicalPath());
end

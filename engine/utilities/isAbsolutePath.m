function resp = isAbsolutePath(pth)
    if isOctave
        resp = is_absolute_filename(pth);
    else
        jvFile = java.io.File(pth);
        resp = jvFile.isAbsolute();
    end
end

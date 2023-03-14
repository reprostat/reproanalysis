function dirRemove(pth)
    if ispc
        [s w] = shell(['rmdir /s /q ' pth]);
    else
        [s w] = shell(['rm -rf ' pth]);
    end
    if s, logging.error(w); end
end

function pth = readLink(pth)
    if iscell(pth)
        pth = cellfun(@which,pth,'UniformOutput',false);
    else
        pth = which(pth);
    end
end

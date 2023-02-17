function pth = readLink(pth)
    if iscell(pth)
        pth = cellfun(@wrapperwhich,pth,'UniformOutput',false);
    else
        pth = wrapperwhich(pth);
    end
end

% TODO - make MATLAB's wich handle absolute path
function pth = wrapperwhich(pth)
    if isOctave || ~isAbsolutePath(pth), pth = which(pth); end
end
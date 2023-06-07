function stream = readStream(fnStream,maximumretry)
    stream = jsondecode(fileRetrieve(fnStream,maximumretry,'content'));

    % Unify structure: content.hash, content.files
    if isfield(stream,'hash') % simple stream
        stream.files = stream;
        stream = rmfield(stream,'hash');
    end
end

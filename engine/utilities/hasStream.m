function resp = hasStream(rap,varargin)

streamName = varargin{end};
streamName = strsplit(streamName,'.'); streamName = streamName{end};

resp = any(strcmp({rap.tasklist.currenttask.outputstreams.name},streamName));

if resp && (numel(varargin) > 1)
    resp = ~isempty(getFileByStream(rap,varargin{:},'streamType','input','isProbe',true));
end

end

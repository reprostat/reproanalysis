function resp = hasStream(rap,varargin)

streamName = varargin{end};
streamName = strsplit(streamName,'.'); streamName = streamName{end};

resp = find(arrayfun(@(s) any(strcmp(s.name,streamName)), rap.tasklist.currenttask.inputstreams),1);
if isempty(resp), resp = false; end

if resp && (numel(varargin) > 1)
    resp = ~isempty(getFileByStream(rap,varargin{:},'streamType','input','isProbe',true));
end

end

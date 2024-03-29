function rap = passStreams(rap,varargin)
    in = getStreamByName(rap,'streamList');

    if ~isempty(varargin), in = setdiff(in,varargin{1}); end
    out = {rap.tasklist.currenttask.outputstreams.name}; if ~iscell(out), out = {out}; end
    for s = 1:numel(in)
        instream = strsplit(in{s},'.'); instream = instream{end};
        if s <= numel(out)
            if ~strcmp(out{s},instream)
                rap = renameStream(rap,rap.tasklist.currenttask.name,'output',out{s},instream);
                logging.info([rap.tasklist.currenttask.name ' output stream: ''' instream '''']);
            end
        else
            rap = renameStream(rap,rap.tasklist.currenttask.name,'output','append',instream);
            logging.info([rap.tasklist.currenttask.name ' output stream: ''' instream '''']);
        end
    end
end

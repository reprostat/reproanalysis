function k = getSourceTaskInd(rap,sourceMod,streamName)

currTask = '';
currTaskNum = rap.tasklist.currenttask.tasknumber;

if nargin == 2 % based on branch
    srcModSel = true(1,currTaskNum-1);
    if isfield(rap.tasklist.currenttask,'branchid') && ~isempty(rap.tasklist.currenttask.branchid)
        srcModSel = cellfun(@(b) startsWith(rap.tasklist.currenttask.branchid,b),{rap.tasklist.main(1:currTaskNum-1).branchid});
    end
    srcModSel = srcModSel & strcmp({rap.tasklist.main(1:currTaskNum-1).name}, sourceMod);
    currTaskNum = find(srcModSel);

else % based on stream name
    streamName = strsplit(streamName,'.');
    if numel(streamName) > 1 % fully specified - simple
        currTaskNum = find(strcmp(arrayfun(@(s) sprintf('%s_%05d',s.name, s.index), rap.tasklist.main(1:currTaskNum-1), 'UniformOutput',false),streamName{1}));
        if ~any(strcmp({rap.tasklist.main(currTaskNum).outputstreams.name},streamName{2}))
            logging.error('Task "%s" does not create stream "%s"',streamName{1},streamName{2});
        end
    else % no spec -> track
        streamName = streamName{1};
        while ~strcmp(currTask,sourceMod)
            inStreams = rap.tasklist.main(currTaskNum).inputstreams;
            srcMatch = strcmp({inStreams.name},streamName);
            if any(srcMatch)
                currTaskNum = inStreams(srcMatch).taskindex;
            else
                logging.error('stream "%s" cannot be tracked beyond task "%s_%05d"',streamName,currTask,currTaskInd);
                currTaskNum = [];
                break;
            end
            currTask = rap.tasklist.main(currTaskNum).name;
            currTaskInd = rap.tasklist.main(currTaskNum).index;
        end
    end
end

k = currTaskNum;


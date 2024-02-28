function resp = getStreamByName(rap,whatToReturn) % 'streamList', <stream name>
    if isOctave(), rePattern= '(?<=\.)?\w*$';
    else, rePattern = '(?<=\.?)\w*$';
    end
    inStreamList = cellfun(@(n) regexp(n{1},rePattern,'match','once'),...
                 arrayfun(@(s) cellstr(s.name),rap.tasklist.currenttask.inputstreams, 'UniformOutput',false),...
                 'UniformOutput',false);
    switch whatToReturn
        case 'streamList'
            resp = inStreamList;
        otherwise
            resp = rap.tasklist.currenttask.inputstreams(strcmp(inStreamList,whatToReturn));
    end
end

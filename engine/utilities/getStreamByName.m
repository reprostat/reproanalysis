function resp = getStreamByName(rap,whatToReturn) % '[orig:]streamList', [orig:]<stream name>
    if isOctave(), rePattern= '(?<=\.)?\w*$';
    else, rePattern = '(?<=\.?)\w*$';
    end

    indStream = 'first'; % new name if renamed
    if startsWith(whatToReturn,'orig:')
        indStream = 'last'; % original name
        whatToReturn = strrep(whatToReturn,'orig:','');
    end

    inStreamList = cellfun(@(n) regexp(char(getItem(n,indStream)),rePattern,'match','once'),...
                 arrayfun(@(s) cellstr(s.name),rap.tasklist.currenttask.inputstreams, 'UniformOutput',false),...
                 'UniformOutput',false);
    switch whatToReturn
        case 'streamList'
            resp = inStreamList;
        otherwise
            resp = rap.tasklist.currenttask.inputstreams(strcmp(inStreamList,whatToReturn));
    end
end

function val = getItem(items,n)
    switch n
        case 'first'
            val = items(1);
        case 'last'
            val = items(end);
    end
end

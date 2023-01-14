function nme = getRunName(rap,j)
    sessions = rap.acqdetails.([getRunType(rap) 's']);

    if ~isempty(sessions(j).name)
        nme = sessions(j).name;
    else
        nme='(unknown)';
    end
end

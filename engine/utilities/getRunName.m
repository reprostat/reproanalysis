function nme = getRunName(rap,j)
    runs = rap.acqdetails.([getRunType(rap) 's']);

    if ~isempty(runs(j).name)
        nme = runs(j).name;
    else
        nme='(unknown)';
    end
end

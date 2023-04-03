function reproaClose()
    global reproacache

    assert(isa(reproacache,'cacheClass'),'reproa is not loaded')

    reproa = reproacache('reproa');
    reproa.close();

    rmpath(fullfile(fileparts([mfilename('fullpath') '.m']),'engine'));
    rmpath(fullfile(fileparts([mfilename('fullpath') '.m']),'external','toolboxes'));
end

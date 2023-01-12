function reproaClose()
    global reproacache

    assert(isa(reproacache,'cacheClass'),'reproa is not loaded')

    reproa = reproacache('reproa');
    reproa.close();
end

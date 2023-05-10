function rap = reproa_smooth(rap,command,varargin)

    switch command
        case 'doit'

            indices = cell2mat(varargin);

            streams = {rap.tasklist.currenttask.inputstreams.name};
            for streamInd = 1:numel(streams)
                P = getFileByStream(rap,rap.tasklist.currenttask.domain,indices,streams{streamInd},'streamType','input');

                % now smooth
                outputF = spm_file(P,'prefix','s');
                arrayfun(@(f) spm_smooth(P{f},outputF{f},getSetting(rap,'FWHM',streamInd)), 1:numel(P));

                putFileByStream(rap,rap.tasklist.currenttask.domain,indices,streams{streamInd},outputF);
            end

        case 'checkrequirements'
            rap = passStreams(rap);
    end

end



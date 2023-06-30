function rap = reproa_smooth(rap,command,varargin)

    switch command
        case 'doit'

            indices = cell2mat(varargin);

            streams = {rap.tasklist.currenttask.inputstreams.name};
            for streamInd = 1:numel(streams)
                % input
                if iscell(streams{streamInd}), streams{streamInd} = streams{streamInd}{end}; end % renamed -> used original
                imgs = getFileByStream(rap,rap.tasklist.currenttask.domain,indices,streams{streamInd},'streamType','input'); imgs0 = imgs;
                if isstruct(imgs), imgs = struct2cell(imgs); imgs = cat(1,imgs{:}); end

                % now smooth
                simgs = spm_file(imgs,'prefix','s');
                arrayfun(@(f) spm_smooth(imgs{f},simgs{f},getSetting(rap,'FWHM',streamInd)), 1:numel(imgs));

                % output
                if isstruct(imgs0)
                    simgs = struct;
                    for f = fieldnames(imgs0)'
                        simgs.(f{1}) = spm_file(imgs0.(f{1}),'prefix','s');
                    end
                end
                putFileByStream(rap,rap.tasklist.currenttask.domain,indices,streams{streamInd},simgs);
            end

        case 'checkrequirements'
            rap = passStreams(rap);
    end

end



function rap = reproa_scale_segmentations(rap, command, subj)

    switch command
        case 'report'

        case 'doit'
            load(char(getFileByStream(rap, 'subject',subj, 'segmentation_stats')),'stats');
            seg = getFileByStream(rap, 'subject',subj, 'normalised_segmentations','content',{'GM' 'WM' 'CSF'});

            pfxEst = getSetting(rap,'estimatefrom');
            for s = fieldnames(seg)'
                switch getSetting(rap,'scaleby')
                    case 'each'
                        sc = stats(strcmp({stats.desc},s{1})).([pfxEst '_mm3']);
                    case 'TIV'
                        sc = stats(4).([pfxEst '_mm3']);
                    otherwise
                        sc = stats(strcmp({stats.desc},getSetting(rap,'scaleby'))).([pfxEst '_mm3']);
                end
                sc = sc/1e3; % mm3 -> l

                V = spm_vol(seg.(s{1}){1});
                Y = spm_read_vols(V)./sc;
                seg.(s{1}){1} = spm_file(seg.(s{1}){1},'prefix','g');
                V.fname = seg.(s{1}){1};
                spm_write_vol(V,Y);
            end
            putFileByStream(rap, 'subject',subj, 'normalised_segmentations',seg);

        case 'checkrequirements'
            % check for stream renaming at source
            streamSpec = rap.tasklist.currenttask.inputstreams(arrayfun(@(s) any(strcmp(s.name,'normalised_segmentations')),rap.tasklist.currenttask.inputstreams));
            streamName = cellstr(streamSpec.name);
            srcrap = setCurrentTask(rap,'task',streamSpec.taskindex);
            srcStreamName = cellstr(srcrap.tasklist.currenttask.outputstreams(arrayfun(@(s) any(strcmp(s.name,'normalised_segmentations')),srcrap.tasklist.currenttask.outputstreams)).name);
            if ~strcmp(streamName{1},srcStreamName{1})
                logging.warning('Stream %s has been renamed at %s (source) to %s',streamName{1},srcrap.tasklist.currenttask.name,srcStreamName{1});
                rap = renameStream(rap,rap.tasklist.currenttask.name,'input',streamName{1},srcStreamName{1});
                logging.info([rap.tasklist.currenttask.name ' input stream: ''' srcStreamName{1} '''']);
            end
            % - update currenttask
            rap = setCurrentTask(rap,'task',rap.tasklist.currenttask.tasknumber);

            rap = passStreams(rap,{'segmentation_stats'});
    end
end

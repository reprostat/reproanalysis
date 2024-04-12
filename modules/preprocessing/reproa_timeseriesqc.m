function rap = reproa_timeseriesqc(rap,command,varargin)

    switch command
        case 'report'
            reportStore = sprintf('sub%d',varargin{1});

            aap = addReport(rap,reportStore,'<table><tr><td>');

            imgList = cellstr(spm_select('FPList',getPathByDomain(rap,rap.tasklist.currenttask.domain,cell2mat(varargin)),...
                                         sprintf('^diagnostic_%s_plot_[0-9]*\\.jpg$',rap.tasklist.currenttask.name)));
            for fn = imgList'
                rap = addReportMedia(rap,reportStore,fn{1},'displayFileName',false);
            end

            imgList = cellstr(spm_select('FPList',getPathByDomain(rap,rap.tasklist.currenttask.domain,cell2mat(varargin)),...
                                         sprintf('^diagnostic_%s_.*svd\\.jpg$',rap.tasklist.currenttask.name)));
            for fn = imgList'
                rap = addReportMedia(rap,reportStore,fn{1},'displayFileName',true);
            end

            aap = addReport(rap,reportStore,'</td></tr></table>');

        case 'doit'

            indices = cell2mat(varargin);
            localRoot = fullfile(getPathByDomain(rap,rap.tasklist.currenttask.domain,indices));

            % input
            inStream = rap.tasklist.currenttask.inputstreams.name;
            if iscell(inStream), inStream = inStream{end}; end % renamed -> used original

            job = [];
            job.imgs{1} = getFileByStream(rap,rap.tasklist.currenttask.domain,indices,inStream);
            job.vf = 0;
            run_timeseriesqc('run','timeseriesqc',job);
            fnImg = job.imgs{1}{1};

            % output
            putFileByStream(rap,rap.tasklist.currenttask.domain,indices,rap.tasklist.currenttask.outputstreams.name,'timeseriesqc.mat');

            % diag
            % - plots
            job = [];
            job.fnQC = getFileByStream(rap,rap.tasklist.currenttask.domain,indices,rap.tasklist.currenttask.outputstreams.name);
            job.doprint = true;
            if hasStream(rap,rap.tasklist.currenttask.domain,indices,'movementparameters')
                job.mocopar = getFileByStream(rap,rap.tasklist.currenttask.domain,indices,'movementparameters');
            end
            run_timeseriesqc('run','timeseriesqc_plot',job);
            for f = [1 2]
                spm_figure('Close',spm_figure('GetWin', sprintf('Graphics%d',f)));
                movefile(spm_file(job.fnQC,'suffix',sprintf('_%02d',f),'ext','jpg'),...
                         fullfile(localRoot,sprintf('diagnostic_%s_plot_%02d.jpg',rap.tasklist.currenttask.name,f)));
            end

            % - images
            for meas = {'meansvd' 'maxsvd' 'varsvd'}
                fnImgDiag = spm_file(fnImg,'prefix',meas{1});
                Y = spm_read_vols(spm_vol(fnImgDiag));

                % -- 11 slices
                stepSl = floor(size(Y,3)/10);
                margSl = (size(Y,3)-stepSl*10)/2;

                fig = mapOverlay(spm_file(fnImg,'number',1),{{fnImgDiag [] [1 prctile(Y(:), 90)]}},'axial',margSl:stepSl:size(Y,3)-margSl);
                print(fig,'-noui',fullfile(localRoot, sprintf('diagnostic_%s_%s.jpg',rap.tasklist.currenttask.name,meas{1})),'-djpeg','-r300');
                close(fig);
            end
end



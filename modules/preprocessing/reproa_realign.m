% realignment

function rap = reproa_realign(rap,command,subj)

switch command
    case 'report'
        reportStore = sprintf('sub%d',subj);

        if subj == 1 % init summary
            rap.report.(mfilename).selectedruns = zeros(1,0);
            rap.report.(mfilename).mvmax = nan(getNByDomain(rap,'subject'),getNByDomain(rap,'fmrirun'),6);
        end
        rap.report.(mfilename).selectedruns = union(rap.report.(mfilename).selectedruns,rap.acqdetails.selectedruns);

        mvmean=[];
        mvmax=[];
        mvstd=[];
        mvall=[];

        addReport(rap,reportStore,'<table><tr>');
        for run=rap.acqdetails.selectedruns
            runName = rap.acqdetails.fmriruns(run).name;
            addReport(rap,reportStore,'<td>');
            addReport(rap,reportStore,['<h3>Run: ' runName '</h3>']);
            fn = spm_select('FPListRec',getPathByDomain(rap,'subject',subj),['^diagnostic_.*' runName '\.jpg']);
            rap = addReportMedia(rap,reportStore,fn,'scaling',0.5,'displayFileName',false);

            parFn = getFileByStream(rap,'fmrirun',[subj run],'movementparameters');
            mv = load(parFn{1});

            rap.report.(mfilename).mvmax(subj,run,:) = max(mv);
            mvstd(end+1,:) = std(mv);
            mvall = [mvall; mv];

            addReport(rap,reportStore,'<h3>Movement maximums</h3>');
            addReport(rap,reportStore,'<table cellspacing="10">');
            addReport(rap,reportStore,sprintf('<tr><td align="right">Run</td><td align="right">x</td><td align="right">y</td><td align="right">z</td><td align="right">rotx</td><td align="right">roty</td><td align="right">rotz</td></tr>',run));
            addReport(rap,reportStore,sprintf('<tr><td align="right">%s</td>',runName));
            addReport(rap,reportStore,sprintf('<td align="right">%8.3f</td>',rap.report.(mfilename).mvmax(subj,run,:)));
            addReport(rap,reportStore,'</tr>');
            addReport(rap,reportStore,'</table>');

            addReport(rap,reportStore,'</td>');
        end
        addReport(rap,reportStore,'</tr></table>');

        varcomp = mean((std(mvall).^2)./(mean(mvstd.^2)));
        addReport(rap,reportStore,'<h3>All variance vs. within run variance</h3><table><tr>');
        addReport(rap,reportStore,sprintf('<td>%8.3f</td>',varcomp));
        addReport(rap,reportStore,'</tr></table>');

		% Summary in case of more subjects
        if getNByDomain(rap,'subject') == 1
            addReport(rap,'moco','<h4>No summary is generated: there is only one subject in the pipeline</h4>');
        elseif subj == numel(rap.acqdetails.subjects) % last subject
            meas = {'Trans - x','Trans - y','Trans - z','Pitch','Roll','Yaw'};

            addReport(rap,'moco',['<h2>Task: ' getTaskDescription(rap,subj,'taskname') '</h2>']);
            addReport(rap,'moco','<table><tr>');

            for run = rap.report.(mfilename).selectedruns
				fn = fullfile(getPathByDomain(rap,'study',[]),['diagnostic_' mfilename '_' rap.acqdetails.fmriruns(run).name '.jpg']);

                mvmax = squeeze(rap.report.(mfilename).mvmax(:,run,:));

                % Boxplot implementation is different in MATLAB and OCATVE -> manual approach
                whisker = 1.5; % Q3+1.5*IQR (we care only for extra large outliers)
                jitter = 0.1; % jitter around position
                barWidth = 0.5;
                jitter = (...
                    1+(rand(size(mvmax))-0.5) .* ...
                    repmat(jitter*2./[1:size(mvmax,2)],size(mvmax,1),1)...
                    ) .* ...
                    repmat([1:size(mvmax,2)],size(mvmax,1),1);

                bpstat = prctile(mvmax,[75 50 25]);
                thrOut = bpstat(1,:)+whisker*(bpstat(1,:) - bpstat(3,:));
                selOut = mvmax > repmat(thrOut,getNByDomain(rap,'subject'),1);
                outVal = mvmax(selOut);
                [~, outMeas] = ind2sub(size(mvmax),find(selOut));
                mvmax(selOut) = NaN;

                fig = figure; hold on;
                for s = 1:size(mvmax,2)
                    % - data
                    scatter(jitter(:,s),mvmax(:,s),'k','filled','SizeData',20,'MarkerFaceAlpha',0.4);
                    % - Q2 (median)
                    plot([s-(barWidth/2) s+(barWidth/2)],[bpstat(2,s) bpstat(2,s)],'b');
                    % - Q1, Q3
                    plot([s-(barWidth/2) s+(barWidth/2) s+(barWidth/2) s-(barWidth/2) s-(barWidth/2)],[bpstat(1,s) bpstat(1,s) bpstat(3,s) bpstat(3,s) bpstat(1,s)],'k');
                    % - whisker
                    plot([s s],[bpstat(1,s) thrOut(s)],'--g')
                    plot([s-(barWidth/4) s+(barWidth/4)],[thrOut(s) thrOut(s)],'g');
                end
                % - outliers
                plot(outMeas,outVal,'*r');

                if ~exist(fn,'file'), print(fig,'-djpeg','-r150',fn); end
                close(fig);

                addReport(rap,'moco','<td valign="top">');
                addReport(rap,'moco',['<h3>Run: ' rap.acqdetails.fmriruns(run).name '</h3>']);
                rap = addReportMedia(rap,'moco',fn,'displayFileName',false);

                % Outliers
                for m = unique(outMeas)'
                    addReport(rap,'moco',['<h4>Outlier(s) in ' meas{m} ':' sprintf(' %s',rap.acqdetails.subjects(selOut(:,m)).subjname) '</h4>']);
                end

                addReport(rap,'moco','</td>');
            end
            addReport(rap,'moco','</tr></table>');
        end
    case 'doit'
        estFlags = getSetting(rap,'eoptions');
        uwestFlags = getSetting(rap,'uoptions');
        resFlags = getSetting(rap,'roptions');
        resFlags.which = [getSetting(rap,'reslicewhich') getSetting(rap,'writemean')];

        imgs = arrayfun(@(r) getFileByStream(rap,'fmrirun',[subj,r],'fmri'), rap.acqdetails.selectedruns);

        % Check if we are using a weighting image
        if hasStream(rap,'weighting_image')

            wImgFile = getFileByStream(rap,'subject',subj,'weighting_image');
            wVol = cell2mat(spm_vol(wImgFile));

            logging.info('Realignment is going to be weighted with:%s', sprintf('\n\t%s',wImgFile{:}));

            % Use the first EPI as a space reference
            rVol = spm_vol([imgs{1},',1']);

            % Check if the dimensions and the orientation of the weighting
            % image match that of the first EPI in the data set.  If not,
            % we reslice the weighting image.
            if ~isequal(wVol.mat, rVol.mat) || ~isequal(wVol.dim, rVol.dim)
                spm_reslice([{rVol.fname}, wImgFile], struct('which',1, 'mean',0, 'interp',0, 'prefix','r'));
                wImgFile = spm_file(wImgFile,'prefix','r');
                wVol = cell2mat(spm_vol(wImgFile));
            end

            % invert if needed
            if rap.tasklist.currenttask.settings.invertweighting
                for v = reshape(wVol,1,[])
                    wY = spm_read_vols(v);
                    wY = 1./wY;
                    spm_write_vol(v, wY);
                end
            end

            % combine if more than 1
            if numel(wImgFile) > 1
                logging.error('NYI');
            end

            estFlags.weight = wImgFile{1};
        else
            estFlags.weight = '';
        end

        job.eoptions = estFlags;

        % Check if we are unwarping
        if isstruct(uwestFlags)
            job.data = [];
            for r = rap.acqdetails.selectedruns
                job.data(end+1).scans = getFileByStream(rap,'fmrirun',[subj,r],'fmri');
                job.data(end).pmscan = getFileByStream(rap,'fmrirun',[subj,r],'fieldmap');
            end
            job.uweoptions = uwestFlags;
            job.uweoptions.basfcn = repmat(job.uweoptions.basfcn,1,2);
            job.uweoptions.expround = strrep(lower(job.uweoptions.expround),'''','');
            job.uwroptions = resFlags;
            spm_run_realignunwarp(job);
        else
            job.data = imgs;
            job.roptions = resFlags;
            spm_run_realign(job);
        end

        %% Describe outputs
        putFileByStream(rap,'subject',subj,'meanfmri',...
                        spm_select('FPList',getPathByDomain(rap,'fmrirun',[subj,min(rap.acqdetails.selectedruns)]),'^mean.*.nii$'));

        for run = rap.acqdetails.selectedruns
            logging.info('Working with run %d: %s', run, rap.acqdetails.fmriruns(run).name)

            rimgs = imgs{rap.acqdetails.selectedruns==run};
            if rap.tasklist.currenttask.settings.reslicewhich ~= 0, rimgs = spm_file(rimgs,'prefix',resFlags.prefix); end
            putFileByStream(rap,'fmrirun',[subj run],'fmri',rimgs);

            outpars = spm_select('FPList',getPathByDomain(rap,'fmrirun',[subj,run]),'^rp_.*.txt$');

            % Sessionwise custom plot or MFP
            if isfield(rap.tasklist.currenttask.settings,'mfp') && rap.tasklist.currenttask.settings.mfp.run
                logging.error('NYI');
%                mw_mfp(outpars);
%                fn=dir(fullfile(pth,'mw_mfp_*.txt'));
%                outpars = fullfile(pth,fn(1).name);
%                if strcmp(rap.options.wheretoprocess,'localsingle')
%                    movefile(...
%                        fullfile(aas_getrunpath(rap,subj,run),'mw_motion.jpg'),...
%                        fullfile(aas_getsubjpath(rap,subj),...
%                        ['diagnostic_aamod_realign_' rap.acqdetails.fmriruns(run).name '.jpg'])...
%                        );
%                end
            else
                % Get the realignment transformations (it also includes between-run movement, unlike the rp-files)...
                load(spm_file(imgs{rap.acqdetails.selectedruns==run},'ext','.mat'),'mat');
                mocomat = [];
                V1 = spm_vol(spm_file(imgs{1},'number',',1'));
                for v = 2:size(mat,3), mocomat(v,:) = spm_imatrix(mat(:,:,v)/V1.mat); end
                mocomat(:,7:end) = [];

                f = realignPlot({mocomat});
                print('-djpeg','-r150','-noui',...
                    fullfile(getPathByDomain(rap,'fmrirun',[subj,run]),...
                    ['diagnostic_aamod_realign_' rap.acqdetails.fmriruns(run).name '.jpg'])...
                    );
                spm_figure('Close',f);
            end

            putFileByStream(rap,'fmrirun',[subj run],'movementparameters', outpars);

			% FD
			FD = [0;sum(abs(diff(load(outpars) * diag([1 1 1 50 50 50]))),2)];
			fname = spm_file(imgs{rap.acqdetails.selectedruns==run},'prefix','fd_','ext','.txt');
			save(fname,'FD','-ascii');
            putFileByStream(rap,'fmrirun',[subj run],'fd', fname);

        end

    case 'checkrequirements'

end
end


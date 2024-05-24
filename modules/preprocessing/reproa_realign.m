% realignment

function rap = reproa_realign(rap,command,varargin)

indices = cell2mat(varargin);
subj = indices(1);
if numel(indices) < 2 % subject-level
    runs = rap.acqdetails.selectedruns;
else % run-level
    runs = indices(2);
end

switch command
    case 'report'
        reportStore = sprintf('sub%d',subj);
        doInitSubject = (numel(indices) < 2 || indices(2) == rap.acqdetails.selectedruns(1));
        doCloseSubject = (numel(indices) < 2 || indices(2) == rap.acqdetails.selectedruns(end));

        if subj == 1 && doInitSubject % init summary
            rap.report.(mfilename).selectedruns = zeros(1,0);
            rap.report.(mfilename).mvmax = nan(getNByDomain(rap,'subject'),getNByDomain(rap,'fmrirun'),6);
        end
        rap.report.(mfilename).selectedruns = union(rap.report.(mfilename).selectedruns,rap.acqdetails.selectedruns);

        if doInitSubject
            rap.report.(mfilename).mvall = [];
            rap.report.(mfilename).mvstd = [];
            addReport(rap,reportStore,'<table><tr>');
        end

        for run = runs
            indRun = find(rap.acqdetails.selectedruns==run);
            runName = rap.acqdetails.fmriruns(run).name;
            addReport(rap,reportStore,'<td>');
            addReport(rap,reportStore,['<h3>Run: ' runName '</h3>']);
            fn = spm_select('FPListRec',getPathByDomain(rap,'subject',subj),['^diagnostic_.*' runName '\.jpg']);
            rap = addReportMedia(rap,reportStore,fn,'scaling',0.5,'displayFileName',false);

            parFn = getFileByStream(rap,'fmrirun',[subj run],'movementparameters');
            mv = load(parFn{1});

            rap.report.(mfilename).mvmax(subj,indRun,:) = max(mv);
            rap.report.(mfilename).mvstd(indRun,:) = std(mv);
            rap.report.(mfilename).mvall = [rap.report.(mfilename).mvall; mv];

            addReport(rap,reportStore,'<h3>Movement maximums</h3>');
            addReport(rap,reportStore,'<table cellspacing="10">');
            addReport(rap,reportStore,sprintf('<tr><td align="right">Run</td><td align="right">x</td><td align="right">y</td><td align="right">z</td><td align="right">rotx</td><td align="right">roty</td><td align="right">rotz</td></tr>',run));
            addReport(rap,reportStore,sprintf('<tr><td align="right">%s</td>',runName));
            addReport(rap,reportStore,sprintf('<td align="right">%8.3f</td>',rap.report.(mfilename).mvmax(subj,run,:)));
            addReport(rap,reportStore,'</tr>');
            addReport(rap,reportStore,'</table>');

            addReport(rap,reportStore,'</td>');
        end

        if doCloseSubject
            addReport(rap,reportStore,'</tr></table>');
            varcomp = mean((std(rap.report.(mfilename).mvall).^2)./...
                           (mean(rap.report.(mfilename).mvstd.^2)));
            addReport(rap,reportStore,'<h3>All variance vs. within run variance</h3><table><tr>');
            addReport(rap,reportStore,sprintf('<td>%8.3f</td>',varcomp));
            addReport(rap,reportStore,'</tr></table>');
        end


		% Summary in case of more subjects
        if getNByDomain(rap,'subject') == 1
            addReport(rap,'moco','<h4>No summary is generated: there is only one subject in the workflow</h4>');
        elseif subj == numel(rap.acqdetails.subjects) % last subject

            if doInitSubject
                meas = {'Trans - x','Trans - y','Trans - z','Pitch','Roll','Yaw'};

                addReport(rap,'moco',['<h2>Task: ' getTaskDescription(rap,1,'taskname') '</h2>']);
                addReport(rap,'moco','<table><tr>');
            end

            for run = runs
                indRun = find(rap.acqdetails.selectedruns==run);
				fn = fullfile(getPathByDomain(rap,'study',[]),['diagnostic_' mfilename '_' rap.acqdetails.fmriruns(run).name '.jpg']);

                mvmax = squeeze(rap.report.(mfilename).mvmax(:,indRun,:));

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
            if doCloseSubject, addReport(rap,'moco','</tr></table>'); end
        end
    case 'doit'
        estFlags = getSetting(rap,'eoptions');
        uwestFlags = getSetting(rap,'uoptions');
        resFlags = getSetting(rap,'roptions');
        resFlags.which = [getSetting(rap,'reslicewhich') getSetting(rap,'writemean')];

        imgs = getFileByStream(rap,rap.tasklist.currenttask.domain,indices,'fmri');

        % Check if we are using a weighting image (only for domain == 'fmrirun')
        if hasStream(rap,'weighting_image')
            if ~strcmp(rap.tasklist.currenttask.domain,'fmrirun')
                logging.error('Using weighting image is supported only in ''fmrirun'' domain!');
            end

            wImgFile = getFileByStream(rap,rap.tasklist.currenttask.domain,indices,'weighting_image');
            if numel(wImgFile) > 1, logging.error('Single weighing image is expected but %d found.',numel(wImgFile)); end
            wImgFile = wImgFile{1};
            wVol = spm_vol(wImgFile);
            logging.info('Realignment is going to be weighted with:%s', wImgFile);

            global defaults
            % Use the first EPI as a space reference
            epiVol = spm_vol([imgs{1},',1']);

            % Check if the weighting image(s) is/are aligned with the reference (first) EPI. If not, we coregister the
            % weighting image(s).
            if ~isequal(wVol.mat, epiVol.mat)
                x = spm_coreg(rVol, wVol, defaults.coreg.estimate);
                spm_get_space(wVol.fname, spm_matrix(x)\spm_get_space(wVol.fname));
                wVol = spm_vol(wVol.fname);
            end

            % Check if the weighting image(s) has/have the same dimensions as the reference (first) EPI. If not, we
            % reslice the weighting image(s).
            flagsReslice = defaults.coreg.write;
            flagsReslice.which = [1 0];
            if ~isequal(wVol.dim, epiVol.dim)
                spm_reslice([epiVol wVol],flagsReslice);
                wVol = spm_vol(spm_file(wVol.fname,'prefix',flagsReslice.prefix));
            end

            % invert if needed
            if rap.tasklist.currenttask.settings.invertweighting
                wY = spm_read_vols(wVol);
                wY = 1./wY;
                spm_write_vol(wVol, wY);
            end

            estFlags.weight = wVol.fname;
        else
            estFlags.weight = '';
        end

        job.eoptions = estFlags;

        % Check if we are unwarping
        if isstruct(uwestFlags)
            job.data = [];
            for r = runs
                job.data(end+1).scans = getFileByStream(rap,'fmrirun',[subj,r],'fmri');
                job.data(end).pmscan = getFileByStream(rap,'fmrirun',[subj,r],'fieldmap');
            end
            job.uweoptions = uwestFlags;
            job.uweoptions.basfcn = repmat(job.uweoptions.basfcn,1,2);
            job.uweoptions.expround = strrep(lower(job.uweoptions.expround),'''','');
            job.uwroptions = resFlags;
            spm_run_realignunwarp(job);
        else
            job.data = cellfun(@(c) {c}, imgs,'UniformOutput',false);
            job.roptions = resFlags;
            spm_run_realign(job);
        end

        %% Describe outputs
        putFileByStream(rap,rap.tasklist.currenttask.domain,indices,'meanfmri',...
                        spm_select('FPList',getPathByDomain(rap,'fmrirun',[subj,min(runs)]),'^mean.*.nii$'));

        for run = runs
            logging.info('Working with run %d: %s', run, rap.acqdetails.fmriruns(run).name)

            rimgs = imgs{runs==run};
            if rap.tasklist.currenttask.settings.reslicewhich ~= 0, rimgs = spm_file(rimgs,'prefix',resFlags.prefix); end
            putFileByStream(rap,'fmrirun',[subj run],'fmri',rimgs);

            outpars = spm_select('FPList',getPathByDomain(rap,'fmrirun',[subj,run]),'^rp_.*.txt$');

            % Runwise custom plot or MFP
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
                load(spm_file(imgs{runs==run},'ext','.mat'),'mat');
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
			fname = spm_file(imgs{runs==run},'prefix','fd_','ext','.txt');
			save(fname,'FD','-ascii');
            putFileByStream(rap,'fmrirun',[subj run],'fd', fname);

        end
end
end


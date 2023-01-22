% realignment

function rap = realign(rap,command,subj)

switch command
%    case 'report'
%        if subj == 1 % init summary
%            rap.report.(mfilename).selectedruns = zeros(1,0);
%            rap.report.(mfilename).mvmax = nan(getNByDomain(rap,'subject'),getNByDomain(rap,'fmrirun',1),6);
%        end
%        rap.report.(mfilename).selectedruns = union(rap.report.(mfilename).selectedruns,rap.acqdetails.selectedruns);
%
%        mvmean=[];
%        mvmax=[];
%        mvstd=[];
%        mvall=[];
%        nrun=numel(rap.acqdetails.selectedruns);
%
%        qq=[];
%
%        rap = aas_report_add(rap,subj,'<table><tr>');
%        for run=rap.acqdetails.selectedruns
%%             if run > aas_getN_bydomain(rap,'run',subj), break; end
%            rap = aas_report_add(rap,subj,'<td>');
%            rap = aas_report_add(rap,subj,['<h3>Session: ' rap.acqdetails.fmriruns(run).name '</h3>']);
%            fn = fullfile(aas_getsubjpath(rap,subj),['diagnostic_aamod_realign_' rap.acqdetails.fmriruns(run).name '.jpg']);
%
%            par = cellstr(aas_getfiles_bystream(rap,subj,run,'realignment_parameter'));
%            parind = cell_index(par,'.txt');
%            mv = load(par{parind});
%
%            if ~exist(fn,'file')
%                if isfield(rap.tasklist.currenttask.settings,'mfp') && rap.tasklist.currenttask.settings.mfp.run
%                    mw_mfp_show(aas_getrunpath(rap,subj,run));
%                    movefile(...
%                        fullfile(aas_getrunpath(rap,subj,run),'mw_motion.jpg'),fn);
%                else
%                    f = aas_realign_graph(par{parind});
%                    print('-djpeg','-r150','-noui',...
%                        fullfile(aas_getsubjpath(rap,subj),...
%                        ['diagnostic_aamod_realignunwarp_' rap.acqdetails.fmriruns(run).name '.jpg'])...
%                        );
%                    close(f);
%                end
%            end
%
%            rap.report.(mfilename).mvmax(subj,run,:)=max(mv);
%            % mvmean(run,:)=mean(mv);
%            % mvstd(run,:)=std(mv);
%            % mvall=[mvall;mv];
%            rap=aas_report_addimage(rap,subj,fn);
%
%            rap = aas_report_add(rap,subj,'<h4>Movement maximums</h4>');
%            rap = aas_report_add(rap,subj,'<table cellspacing="10">');
%            rap = aas_report_add(rap,subj,sprintf('<tr><td align="right">Sess</td><td align="right">x</td><td align="right">y</td><td align="right">z</td><td align="right">rotx</td><td align="right">roty</td><td align="right">rotz</td></tr>',run));
%            rap = aas_report_add(rap,subj,sprintf('<tr><td align="right">%d</td>',run));
%            rap = aas_report_add(rap,subj,sprintf('<td align="right">%8.3f</td>',rap.report.(mfilename).mvmax(subj,run,:)));
%            rap = aas_report_add(rap,subj,sprintf('</tr>',run));
%            rap = aas_report_add(rap,subj,'</table>');
%
%            rap = aas_report_add(rap,subj,'</td>');
%        end;
%        rap = aas_report_add(rap,subj,'</tr></table>');
%
%        varcomp=mean((std(mvall).^2)./(mean(mvstd.^2)));
%        rap = aas_report_add(rap,subj,'<h3>All variance vs. within run variance</h3><table><tr>');
%        rap = aas_report_add(rap,subj,sprintf('<td>%8.3f</td>',varcomp));
%        rap = aas_report_add(rap,subj,'</tr></table>');
%
%		% Summary in case of more subjects [TA]
%        if (subj > 1) && (subj == numel(rap.acqdetails.subjects)) % last subject
%            meas = {'Trans - x','Trans - y','Trans - z','Pitch','Roll','Yaw'};
%
%            stagerepname = rap.tasklist.currenttask.name;
%            if ~isempty(rap.tasklist.currenttask.extraparameters)
%                stagerepname = [stagerepname rap.tasklist.currenttask.extraparameters.rap.directory_conventions.analysisid_suffix];
%            end
%            rap = aas_report_add(rap,'moco',['<h2>Stage: ' stagerepname '</h2>']);
%            rap = aas_report_add(rap,'moco','<table><tr>');
%
%            for run=rap.report.(mfilename).selectedruns
%				fn = fullfile(aas_getstudypath(rap),['diagnostic_aamod_realign_' rap.acqdetails.fmriruns(run).name '.jpg']);
%
%                mvmax = squeeze(rap.report.(mfilename).mvmax(:,run,:));
%
%                jitter = 0.1; % jitter around position
%                jitter = (...
%                    1+(rand(size(mvmax))-0.5) .* ...
%                    repmat(jitter*2./[1:size(mvmax,2)],size(mvmax,1),1)...
%                    ) .* ...
%                    repmat([1:size(mvmax,2)],size(mvmax,1),1);
%
%                f = figure; hold on;
%                boxplot(mvmax,'label',meas);
%                for s = 1:size(mvmax,2)
%                    scatter(jitter(:,s),mvmax(:,s),'k','filled','MarkerFaceAlpha',0.4);
%                end
%
%                boxValPlot = getappdata(getappdata(gca,'boxplothandle'),'boxvalplot');
%                set(f,'Renderer','zbuffer');
%                if ~exist(fn,'file'), print(f,'-djpeg','-r150',fn); end
%                close(f);
%
%                rap = aas_report_add(rap,'moco','<td valign="top">');
%                rap = aas_report_add(rap,'moco',['<h3>Session: ' rap.acqdetails.fmriruns(run).name '</h3>']);
%                rap=aas_report_addimage(rap,'moco',fn);
%
%                for ibp = 1:numel(meas)
%                    bp = boxValPlot(ibp,:);
%                    subjs = ' None';
%                    if bp.numFiniteHiOutliers
%                        subjs = [' ' num2str(sort(cell2mat(bp.outlierrows)'))];
%                    end
%                    rap = aas_report_add(rap,'moco',sprintf('<h4>Outlier(s) in %s:%s</h4>',meas{ibp},subjs));
%                end
%
%                rap = aas_report_add(rap,'moco','</td>');
%            end
%            rap = aas_report_add(rap,'moco','</tr></table>');
%        elseif numel(rap.acqdetails.subjects) == 1
%            rap = aas_report_add(rap,'moco','<h4>No summary is generated: there is only one subject in the pipeline</h4>');
%        end
    case 'doit'

        % Get realignment defaults from the XML!
        estFlags = getSetting(rap,'eoptions');
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

            estFlags.PW = wImgFile{1};
        end

        % Run the realignment
        spm_realign(imgs, estFlags);

        % Run the reslicing
        spm_reslice(imgs, resFlags);

        %% Describe outputs
        putFileByStream(rap,'subject',subj,'meanfmri',spm_select('FPList',getPathByDomain(rap,'fmrirun',[subj,min(rap.acqdetails.selectedruns)]),'^mean.*.nii$'));

        for run = rap.acqdetails.selectedruns
            logging.info('Working with run %d: %s', run, rap.acqdetails.fmriruns(run).name)

            rimgs = imgs{rap.acqdetails.selectedruns==run};
            if rap.tasklist.currenttask.settings.reslicewhich ~= 0, rimgs = spm_file(rimgs,'prefix','r'); end
            putFileByStream(rap,'fmrirun',[subj run],'fmri',rimgs);

            % Get the realignment parameters...
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
                f = realignPlot(outpars);
                print('-djpeg','-r150','-noui',...
                    fullfile(getPathByDomain(rap,'fmrirun',[subj,run]),...
                    ['diagnostic_aamod_realign_' rap.acqdetails.fmriruns(run).name '.jpg'])...
                    );
                spm_figure('Close',f);
            end

            putFileByStream(rap,'fmrirun',[subj run],'realignment_parameter', outpars);

			% FD
			FD = [0;sum(abs(diff(load(outpars) * diag([1 1 1 50 50 50]))),2)];
			fname = spm_file(imgs{rap.acqdetails.selectedruns==run},'prefix','fd_');
			save(fname,'FD','-ascii');
            putFileByStream(rap,'fmrirun',[subj run],'fd', fname);

        end

    case 'checkrequirements'

end
end


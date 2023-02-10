function rap = firstlevelthreshold(rap,command,subj)

    switch command

        case 'report'

%            % collect contrast names and prepare summary
%            contrasts = aas_getsetting(aas_setcurrenttask(rap,rap.internal.inputstreamsources{rap.tasklist.currenttask.modulenumber}.stream(1).sourcenumber),'contrasts');
%            cons = [contrasts(2:end).con];
%            conNames = {cons.name};
%            [~,a] = unique(conNames,'first');
%            conNames = conNames(sort(a));
%
%            if subj == 1 % first
%                for C = 1:numel(conNames)
%                    if  ~isfield(rap.report,sprintf('html_C%02d',C))
%                        rap.report.(sprintf('html_C%02d',C)).fname = fullfile(rap.report.condir,[rap.report.fbase sprintf('_C%02d.htm',C)]);
%                        rap = aas_report_add(rap,'C00',...
%                            sprintf('<a href="%s" target=_top>%s</a><br>',...
%                            rap.report.(sprintf('html_C%02d',C)).fname,...
%                            ['Contrast: ' conNames{C}]));
%                        rap = aas_report_add(rap,sprintf('C%02d',C),['HEAD=Contrast: ' conNames{C}]);
%                    end
%                    if ~isempty(rap.tasklist.currenttask.extraparameters.rap.directory_conventions.analysisid_suffix)
%                        rap = aas_report_add(rap,sprintf('C%02d',C),sprintf('<h2>Branch: %s</h2>',...
%                            rap.tasklist.currenttask.extraparameters.rap.directory_conventions.analysisid_suffix(2:end)));
%                    end
%                end
%            end
%
%            fnSPM = aas_getfiles_bystream(rap, subj,'firstlevel_spm');
%            load(fnSPM,'SPM');
%
%            % sanity check -- make sure SPM.swd has the correct path
%            if ~isequal(SPM.swd, spm_file(fnSPM,'path')), SPM.swd = spm_file(fnSPM,'path'); end
%
%            for C = 1:numel(SPM.xCon)
%
%                conName = strrep_multi(SPM.xCon(C).name,{' ' ':' '>'},{'' '_' '-'});
%                conInd = find(strcmp(conNames,SPM.xCon(C).name));
%                if isempty(conInd), continue, end
%
%                rap = aas_report_add(rap,sprintf('C%02d',conInd),['Subject: ' basename(aas_getsubjpath(rap,subj)) '<br>']);
%
%                rap = aas_report_add(rap,subj,sprintf('<h4>%02d. %s</h4>',conInd,conName));
%
%                f{1} = fullfile(aas_getsubjpath(rap,subj),...
%                    sprintf('diagnostic_aamod_firstlevel_threshold_C%02d_%s_overlay_3_001.jpg',conInd,conName));
%
%                % older versions didn't create overlay/renders if no voxels
%                % survived thresholding, ergo the check here. We now create
%                % all images, but this check doesn't hurt, and may be useful
%                % if generating a report on an old extant analysis
%
%                if exist(f{1},'file')
%
%                    tstat = dlmread(strrep(f{1},'_overlay_3_001.jpg','.txt'));
%
%                    f{2} = fullfile(aas_getsubjpath(rap,subj),...
%                        sprintf('diagnostic_aamod_firstlevel_threshold_C%02d_%s_render.jpg',conInd,conName));
%
%                    % add overlay and render images to single subject report...
%
%                    rap = aas_report_add(rap, subj,'<table><tr>');
%                    rap = aas_report_add(rap, subj, sprintf('T = %2.2f - %2.2f</tr><tr>', tstat(1), tstat(2)));
%                    for i = 1:2
%                        rap = aas_report_add(rap, subj,'<td>');
%                        rap = aas_report_addimage(rap, subj, f{i});
%                        rap = aas_report_add(rap, subj,'</td>');
%                    end
%
%                    % add SPM stats table
%                    statsfname = fullfile(aas_getsubjpath(rap,subj),sprintf('table_firstlevel_threshold_C%02d_%s.jpg', conInd, conName));
%                    if ~exist(statsfname,'file')
%                        make_stats_table(SPM, statsfname, C, ...
%                            rap.tasklist.currenttask.settings.threshold.p, ...
%                            rap.tasklist.currenttask.settings.threshold.correction);
%                    end
%                    rap = aas_report_add(rap, subj,'<td>');
%                    rap = aas_report_addimage(rap, subj, statsfname);
%                    rap = aas_report_add(rap, subj,'</td>');
%
%                    rap = aas_report_add(rap,subj,'</tr></table>');
%
%                    % ...also add images & table to module report
%
%                    rap = aas_report_add(rap,sprintf('C%02d',conInd),'<table><tr>');
%                    rap = aas_report_add(rap,sprintf('C%02d',conInd),sprintf('T = %2.2f - %2.2f</tr><tr>', tstat(1), tstat(2)));
%                    for i = 1:2
%                        rap = aas_report_add(rap, sprintf('C%02d',conInd),'<td>');
%                        rap = aas_report_addimage(rap,sprintf('C%02d',conInd), f{i});
%                        rap = aas_report_add(rap,sprintf('C%02d',conInd),'</td>');
%                    end
%                    rap = aas_report_add(rap, sprintf('C%02d',conInd),'<td>');
%                    rap = aas_report_addimage(rap, sprintf('C%02d',conInd), statsfname);
%                    rap = aas_report_add(rap,sprintf('C%02d',conInd),'</td>');
%                    rap = aas_report_add(rap,sprintf('C%02d',conInd),'</tr></table>');
%
%                end
%
%            end

        case 'doit'
            localRoot = getPathByDomain(rap,'subject',subj);

            fnSPM = getFileByStream(rap,'subject',subj,'firstlevel_spm');
            load(fnSPM{1},'SPM');
            anadir = spm_file(fnSPM{1},'path');

            fnThr = cell(1,numel(SPM.xCon));
            fnCl = cell(1,numel(SPM.xCon));
            for c = 1:numel(SPM.xCon)
                conName = strreps(SPM.xCon(c).name,{' ' ':' '>'},{'' '_' '-'});
                STAT = SPM.xCon(c).STAT;
                df = [SPM.xCon(c).eidf SPM.xX.erdf];
                XYZ  = SPM.xVol.XYZ;
                S    = SPM.xVol.S;   % Voxel
                R    = SPM.xVol.R;   % RESEL
                V = SPM.xCon(c).Vspm; V.fname = spm_file(V.fname,'path',anadir);
                Z = spm_get_data(V,XYZ);
                dim = V.dim;
                n = 1; % No conjunction (HARD-CODED)

                % Height threshold filtering
                corrThr = getSetting(rap,'threshold.correction');
                pThr = getSetting(rap,'threshold.p');
                switch corrThr
                    case 'iTT'
                        logging.error('Not yet implemented!');
%                        [Z, XYZ, th] = spm_uc_iTT(Z,XYZ,pThr,1);
                    case 'FWE'
                        u = spm_uc(pThr,df,STAT,R,n,S);
                    case 'FDR'
                        u = spm_uc_FDR(pThr,df,STAT,n,V,0);
                    case 'none'
                        u = spm_u(pThr^(1/n),df,STAT);
                end
                Q      = find(Z > u);
                Z      = Z(:,Q);
                XYZ    = XYZ(:,Q);
                if isempty(Q), logging.info('No voxels survive height threshold u=%0.2g',u);
                else
                    % Extent threshold filtering
                    if ischar(getSetting(rap,'threshold.extent')) % probability-based
                        k = strsplit(getSetting(rap,'threshold.extent'),':'); k{2} = str2double(k{2});
                        iSPM = SPM;
                        iSPM.Ic = c;
                        iSPM.thresDesc = corrThr;
                        iSPM.u = pThr;
                        iSPM.k = 0;
                        iSPM.Im = [];
                        [~,xSPM] = spm_getSPM(iSPM);
                        T = spm_list('Table',xSPM);
                        switch k{1}
                            case {'FWE' 'FDR'}
                                k{1} = ['p(' k{1} '-corr)'];
                            case {'none'}
                                k{1} = 'p(unc)';
                        end
                        pInd = strcmp(T.hdr(1,:),'cluster') & strcmp(T.hdr(2,:),k{1});
                        kInd = strcmp(T.hdr(2,:),'equivk');
                        k = min(cell2mat(T.dat(cellfun(@(p) ~isempty(p) && p<k{2}, T.dat(:,pInd)),kInd)));
                        if isempty(k), k = Inf; end
                    else
                        k = getSetting(rap,'threshold.extent');
                    end

                    A     = spm_clusters(XYZ);
                    Q     = [];
                    for i = 1:max(A)
                        j = find(A == i);
                        if numel(j) >= k, Q = [Q j]; end
                    end
                    Z     = Z(:,Q);
                    XYZ   = XYZ(:,Q);
                    if isempty(Q), logging.info('No voxels survive extent threshold k=%0.2g',k); end
                end

                if ~isempty(Q)
                    % Reconstruct
                    Yepi  = zeros(dim(1),dim(2),dim(3));
                    indx = sub2ind(dim,XYZ(1,:)',XYZ(2,:)',XYZ(3,:)');
                    Yepi(indx) = Z;
                    fnThr{c} = spm_file(V.fname,'basename',strrep(spm_file(V.fname,'basename'),'spm','thr'));
                    V.fname = fnThr{c};
                    V.descrip = sprintf('thr{%s_%1.4f;ext_%d}%s',corrThr,pThr,k,V.descrip(strfind(V.descrip,'}')+1:end));
                    spm_write_vol(V,Yepi);

                    % Cluster
                    global reproacache
                    switch getSetting(rap,'cluster.method')
                        case 'fusionwatershed'
                            FWS = reproacache('toolbox.fws');
                            FWS.load;
                            settings = getSetting(rap,'cluster.options.fusionwatershed');
                            obj = fws.generate_ROI(fnThr{c},...
                                'threshold_method','z','threshold_value',0.1,...
                                'filter',settings.extentprethreshold,'radius',settings.searchradius,'merge',settings.mergethreshold,...
                                'plot',false,'output',true);

                            % - exclude small (<k) ROIs
                            smallROIs = obj.table.ROIid(obj.table.Volume < k);
                            obj.label(reshape(arrayfun(@(l) any(l == smallROIs), obj.label(:)), obj.grid.d)) = 0;
                            obj.table(arrayfun(@(l) any(l == smallROIs), obj.table.ROIid),:) = [];

                            % - save results
                            fnCl{c} = spm_file(fnThr{c},'suffix','_cluster');
                            save.vol(obj.label,obj.grid,spm_file(fnCl{c},'ext',''),'Compressed',false);
                            writetable(obj.table,spm_file(fnCl{c},'ext','csv'));
                            FWS.unload;
                    end

                    % Overlay
                    % - edges of activation
                    slims = ones(4,2);
                    sAct = arrayfun(@(x) anyall(Yepi(x,:,:)), 1:size(Yepi,1));
                    if numel(find(sAct))<2, slims(1,:) = [1 size(Yepi,1)];
                    else, slims(1,:) = [find(sAct,1,'first') find(sAct,1,'last')]; end
                    sAct = arrayfun(@(y) anyall(Yepi(:,y,:)), 1:size(Yepi,2));
                    if numel(find(sAct))<2, slims(2,:) = [1 size(Yepi,2)];
                    else, slims(2,:) = [find(sAct,1,'first') find(sAct,1,'last')]; end
                    sAct = arrayfun(@(z) anyall(Yepi(:,:,z)), 1:size(Yepi,3));
                    if numel(find(sAct))<2, slims(3,:) = [1 size(Yepi,3)];
                    else, slims(3,:) = [find(sAct,1,'first') find(sAct,1,'last')]; end
                    % - convert to mm
                    slims = sort(V.mat*slims,2);
                    % - extend if too narrow (min. 50mm)
                    slims = slims + (repmat([-25 25],4,1).*repmat(diff(slims,[],2)<50,1,2));

                    % - draw
                    axis = {'sagittal','coronal','axial'};
                    for a = 1:3
                        [fig, v] = mapOverlay(getSetting(rap,'overlay.background'),fnThr(c),axis{a},slims(a,1):getSetting(rap,'overlay.distancebetweenslices'):slims(a,2));

                        if ~isempty(getSetting(rap,'overlay.description'))
                            annotation('textbox',[0 0.5 0.5 0.5],'String',getSetting(rap,'overlay.description'),'FitBoxToText','on','fontweight','bold','color','y','fontsize',18,'backgroundcolor','k');
                        end

                        spm_print(fullfile(localRoot, sprintf('diagnostic_%s_C%02d_%s_overlay_%d.jpg',mfilename,c,conName,a)),fig,'jpg');
                    end
                    dlmwrite(fullfile(localRoot, sprintf('diagnostic_aamod_firstlevel_threshold_C%02d_%s.txt',c,conName)),[min(v(v~=0)), max(v)]);

                    % Render
                    % FYI: Render should always work regardless of template type because it maps input into MNI, if necessary.
                    % However, native maps may be misaligned
                    tSPM = reproacache('toolbox.spm');

                    % - workarounds
                    % -- render fails with only one active voxel
                    if numel(Z)  < 2
                        Z = horzcat(Z,Z);
                        XYZ = horzcat(XYZ,XYZ);
                    end
                    % -- render fails with single first slice
                    for a = 1:3
                        if all(XYZ(a,:)==1)
                            Z = horzcat(Z,Z(end));
                            XYZ = horzcat(XYZ,XYZ(:,end)+circshift([1;0;0],a-1));
                        end
                    end

                    % - draw
                    dat.XYZ = XYZ;
                    dat.t = Z';
                    dat.mat = SPM.xVol.M;
                    dat.dim = dim;
                    rendfile  = rap.directoryconventions.render;
                    if ~exist(rendfile,'file') && (rendfile(1) ~= '/'), rendfile = fullfile(tSPM.toolPath,rendfile); end
                    global prevrend
                    prevrend = struct('rendfile',rendfile, 'brt',0.5, 'col',eye(3));
                    out = spm_render(dat,0.5,rendfile); spm_figure('Close','Graphics');
                    img = vertcat(horzcat(out{1},out{3},out{5}),horzcat(out{2},out{4},out{6}));
                    fig = figure;
                    imshow(img,'Border','tight');

                    if ~isempty(getSetting(rap,'overlay.description'))
                        annotation('textbox',[0 0.5 0.5 0.5],'String',getSetting(rap,'overlay.description'),'FitBoxToText','on','fontweight','bold','color','y','fontsize',18,'backgroundcolor','k');
                    end

                    print(fig,'-noui',fullfile(localRoot,sprintf('diagnostic_%s_C%02d_%s_render.jpg',mfilename,c,conName)),'-djpeg','-r300');
                    close(fig);
                end
            end

            % Describe outputs
            fnThr(cellfun(@isempty, fnThr)) = [];
            fnCl(cellfun(@isempty, fnCl)) = [];
            if ~isempty(fnThr)
                putFileByStream(rap,'subject',subj,'firstlevel_thresholdedmaps',fnThr);
            end
            if ~isempty(fnCl)
                putFileByStream(rap,'subject',subj,'firstlevel_clusters',fnCl);
            end

        case 'checkrequirements'
            % Background (structural -> FSLT1 -> SPMT1)
            bgFile = '';
            if strcmp(getSetting(rap,'overlay.background'),'structural') && hasStream(rap,'subject',subj,'structural')
                logging.warning('(%s): You should verify background ''structural'' is in the same space as ''fmri''.', mfilename);
                bgFile = char(getFileByStream(rap,'subject',subj,'structural'));
            end
            if (strcmp(getSetting(rap,'overlay.background'),'FSLT1') || isempty(bgFile)) && isfield(rap.directoryconventions,'FSLdir')
                bgFile = fullfile(rap.directoryconventions.FSLT1);
                if ~exist(bgFile,'file'), bgFile = fullfile(rap.directoryconventions.FSLdir,bgFile); end
                if ~exist(bgFile,'file'), bgFile = ''; end
            end
            if isempty(bgFile)
                bgFile = fullfile(rap.directoryconventions.SPMT1);
                if ~exist(bgFile,'file')
                    global reproacache
                    tSPM = reproacache('toolbox.spm');
                    bgFile = fullfile(tSPM.toolPath,bgFile);
                end
                if ~exist(bgFile,'file'), bgFile = ''; end
            end
            if isempty(bgFile), logging.error('No background has been found');
            else, bgFile = readLink(bgFile);
            end

            rap.tasksettings.firstlevelthreshold(rap.tasklist.currenttask.index).overlay.background = bgFile;

            % Clustering may require external toolbox
            global reproacache
            switch getSetting(rap,'cluster.method')
                case 'fusionwatershed'
                    if ~reproacache.isKey('toolbox.fws')
                        logging.warning('Fusion-Watershed is not installed! --> clustering will not be performed');
                        rap.tasksettings.firstlevelthreshold(rap.tasklist.currenttask.index).cluster.method = 'none';
                    end
            end
    end

end

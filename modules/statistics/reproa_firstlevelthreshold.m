function rap = reproa_firstlevelthreshold(rap,command,subj)

    switch command

        case 'report'
            reportStore = sprintf('sub%d',subj);

            load(char(getFileByStream(rap,'subject',subj,'firstlevel_spm')),'SPM');
            conNames = {SPM.xCon.name};

            % Prepare summary
            if subj == 1 % first
                for conInd = 1:numel(conNames)
                    if  ~isfield(rap.report,sprintf('con%d',conInd))
                        rap.report.(sprintf('con%d',conInd)).fname = fullfile(rap.report.conDir,[sprintf('con-%02d.html',conInd)]);
                        addReport(rap,'con0',sprintf('<a href="%s" target=_top>%s</a><br>',...
                            rap.report.(sprintf('con%d',conInd)).fname,...
                            ['Contrast: ' conNames{conInd}]...
                            ));
                        rap = addReport(rap,sprintf('con%d',conInd),['HEAD=Contrast: ' conNames{conInd}]);
                    end
                    if ~isempty(rap.tasklist.currenttask.extraparameters)
                        addReport(rap,sprintf('con%d',conInd),sprintf('<h2>Branch: %s</h2>',...
                            rap.tasklist.currenttask.extraparameters.rap.directoryconventions.analysisidsuffix(2:end)...
                            ));
                    end
                end
            end

            for conInd = 1:numel(conNames)
                addReport(rap,reportStore,sprintf('<h4>%02d. %s</h4>',conInd,conNames{conInd}));
                conFiles = cellstr(spm_select('FPList',getPathByDomain(rap,'subject',subj),['^diagnostic_' rap.tasklist.currenttask.name '.*' conNames{conInd} '.*$']));
                if isempty(conFiles{1}), continue; end
                statMinMax = dlmread(conFiles{endsWith(conFiles,'txt')});
                addReport(rap,reportStore,sprintf('Range of statistics: %1.3f - %1.3f',statMinMax));
                rap = addReportMedia(rap,reportStore,conFiles(lookFor(conFiles,'table')),'scaling',1/3,'displayFileName',false);
                rap = addReportMedia(rap,reportStore,conFiles(lookFor(conFiles,'overlay')),'scaling',1/3,'displayFileName',false);

                % Summary - axial and table(s)
                addReport(rap,sprintf('con%d',conInd),rap.acqdetails.subjects(subj).subjname);
                addReportMedia(rap,sprintf('con%d',conInd),conFiles(lookFor(conFiles,'overlay_3') | lookFor(conFiles,'table')),'scaling',1/3,'displayFileName',false);
            end

        case 'doit'
            localRoot = getPathByDomain(rap,'subject',subj);

            fnSPM = getFileByStream(rap,'subject',subj,'firstlevel_spm');
            load(fnSPM{1},'SPM');
            anadir = spm_file(fnSPM{1},'path');

            fnThr = cell(1,numel(SPM.xCon));
            fnCl = cell(1,numel(SPM.xCon));
            for c = 1:numel(SPM.xCon)
                conName = strreps(SPM.xCon(c).name,{' ' ':' '>'},{'' '_' '-'});
                logging.info(['Running - ' conName ' ...']);
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
                    % Table
                    iSPM = SPM;
                    iSPM.Ic = c;
                    iSPM.thresDesc = corrThr;
                    iSPM.u = pThr;
                    iSPM.k = k;
                    iSPM.Im = [];
                    [~,xSPM] = spm_getSPM(iSPM);
                    h = list_table(xSPM);
                    print_table(h,fullfile(localRoot,sprintf('diagnostic_%s_C%02d_%s_table.jpg',rap.tasklist.currenttask.name,c,conName)));
                    close(h);

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
                        [fig, v] = mapOverlay(getSetting(rap,'overlay.background'),{{fnThr{c} [] [1e-6 prctile(Yepi(Yepi>0), 98)]}},axis{a},slims(a,1):getSetting(rap,'overlay.distancebetweenslices'):slims(a,2));

                        if ~isempty(getSetting(rap,'overlay.description'))
                            annotation('textbox',[0 0.5 0.5 0.5],'String',getSetting(rap,'overlay.description'),'FitBoxToText','on','fontweight','bold','color','y','fontsize',18,'backgroundcolor','k');
                        end

                        print(fig,'-noui',fullfile(localRoot, sprintf('diagnostic_%s_C%02d_%s_overlay_%d.jpg',rap.tasklist.currenttask.name,c,conName,a)),'-djpeg','-r300');
                    end
                    dlmwrite(fullfile(localRoot, sprintf('diagnostic_%s_C%02d_%s.txt',rap.tasklist.currenttask.name,c,conName)),[min(v(v~=0)), max(v)]);

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

                    print(fig,'-noui',fullfile(localRoot,sprintf('diagnostic_%s_C%02d_%s_render.jpg',rap.tasklist.currenttask.name,c,conName)),'-djpeg','-r300');
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
            global reproacache
            reproa = reproacache('reproa');

            % Background (structural -> FSLT1 -> SPMT1)
            bgFile = '';
            if strcmp(getSetting(rap,'overlay.background'),'structural') && hasStream(rap,'subject',subj,'structural')
                logging.warning('(%s): You should verify background ''structural'' is in the same space as ''fmri''.', mfilename);
                bgFile = char(getFileByStream(rap,'subject',subj,'structural'));
            end
            if (strcmp(getSetting(rap,'overlay.background'),'FSLT1') || isempty(bgFile)) && ismember('fsl',reproa.extensions)
                bgFile = fullfile(rap.directoryconventions.FSLT1);
                if ~exist(bgFile,'file'), bgFile = fullfile(rap.directoryconventions.fsldir,bgFile); end
                if ~exist(bgFile,'file'), bgFile = ''; end
            end
            if strcmp(getSetting(rap,'overlay.background'),'SPMT1') || isempty(bgFile)
                bgFile = rap.directoryconventions.SPMT1;
                if ~isAbsolutePath(bgFile)
                    tSPM = reproacache('toolbox.spm');
                    bgFile = fullfile(tSPM.toolPath,bgFile);
                end
                if ~exist(bgFile,'file'), bgFile = ''; end
            end
            if isempty(bgFile), logging.error('No background has been found'); end

            rap.tasksettings.reproa_firstlevelthreshold(rap.tasklist.currenttask.index).overlay.background = bgFile;

            % Clustering may require external toolbox
            global reproacache
            switch getSetting(rap,'cluster.method')
                case 'fusionwatershed'
                    if ~reproacache.isKey('toolbox.fws')
                        logging.warning('Fusion-Watershed is not installed! --> clustering will not be performed');
                        rap.tasksettings.reproa_firstlevelthreshold(rap.tasklist.currenttask.index).cluster.method = 'none';
                    end
            end
    end

end

function Fgraph = list_table(xSPM)
% this is essentially spm_list('Display',...) without the parts that
%   - expect the SPM interactive windows to be up
%   - don't play nice with save-to-jpeg.

    TabDat = spm_list('Table',xSPM);

    %-Setup Graphics panel
    %----------------------------------------------------------------------
    Fgraph = spm_figure('CreateSatWin');
    set(Fgraph,'Renderer','opengl');

    Fgraph = spm_figure('FindWin','Satellite');
    ht = 0.85; bot = 0.14;

    spm_results_ui('Clear',Fgraph)
    FS     = spm('FontSizes');           %-Scaled font sizes
    PF     = spm_platform('fonts');      %-Font names (for this platform)

    %-Table axes & Title
    %----------------------------------------------------------------------
    hAx   = axes('Parent',Fgraph,...
                    'Position',[0.025 bot 0.9 ht],...
                    'DefaultTextFontSize',FS(8),...
                    'DefaultTextInterpreter','Tex',...
                    'DefaultTextVerticalAlignment','Baseline',...
                    'Tag','SPMList',...
                    'Units','points',...
                    'Visible','off');

    AxPos = get(hAx,'Position'); set(hAx,'YLim',[0,AxPos(4)])
    dy    = FS(9);
    y     = floor(AxPos(4)) - dy;

% this is not playing well with jpeg save
%
%     text(0,y,['Statistics:  \it\fontsize{',num2str(FS(9)),'}',TabDat.tit],...
%               'FontSize',FS(11),'FontWeight','Bold');   y = y - dy/2;

    line([0 1],[y y],'LineWidth',3,'Color','r'),        y = y - 9*dy/8;

    %-Display table header
    %----------------------------------------------------------------------
    set(hAx,'DefaultTextFontName',PF.helvetica,'DefaultTextFontSize',FS(8))

    Hs = []; Hc = []; Hp = [];
    h  = text(0.01,y, [TabDat.hdr{1,1} '-level'],'FontSize',FS(9)); Hs = [Hs,h];
    h  = line([0,0.11],[1,1]*(y-dy/4),'LineWidth',0.5,'Color','r'); Hs = [Hs,h];
    h  = text(0.02,y-9*dy/8,    TabDat.hdr{3,1});              Hs = [Hs,h];
    h  = text(0.08,y-9*dy/8,    TabDat.hdr{3,2});              Hs = [Hs,h];

    h = text(0.22,y, [TabDat.hdr{1,3} '-level'],'FontSize',FS(9));    Hc = [Hc,h];
    h = line([0.14,0.44],[1,1]*(y-dy/4),'LineWidth',0.5,'Color','r'); Hc = [Hc,h];
    h  = text(0.15,y-9*dy/8,    TabDat.hdr{3,3});              Hc = [Hc,h];
    h  = text(0.24,y-9*dy/8,    TabDat.hdr{3,4});              Hc = [Hc,h];
    h  = text(0.34,y-9*dy/8,    TabDat.hdr{3,5});              Hc = [Hc,h];
    h  = text(0.39,y-9*dy/8,    TabDat.hdr{3,6});              Hc = [Hc,h];

    h = text(0.64,y, [TabDat.hdr{1,7} '-level'],'FontSize',FS(9));    Hp = [Hp,h];
    h = line([0.48,0.88],[1,1]*(y-dy/4),'LineWidth',0.5,'Color','r'); Hp = [Hp,h];
    h  = text(0.49,y-9*dy/8,    TabDat.hdr{3,7});              Hp = [Hp,h];
    h  = text(0.58,y-9*dy/8,    TabDat.hdr{3,8});              Hp = [Hp,h];
    h  = text(0.67,y-9*dy/8,    TabDat.hdr{3,9});              Hp = [Hp,h];
    h  = text(0.75,y-9*dy/8,    TabDat.hdr{3,10});             Hp = [Hp,h];
    h  = text(0.82,y-9*dy/8,    TabDat.hdr{3,11});             Hp = [Hp,h];

    text(0.92,y - dy/2,TabDat.hdr{3,12},'Fontsize',FS(8));

    %-Move to next vertical position marker
    %----------------------------------------------------------------------
    y     = y - 7*dy/4;
    line([0 1],[y y],'LineWidth',1,'Color','r')
    y     = y - 5*dy/4;
    y0    = y;

    %-Table filtering note
    %----------------------------------------------------------------------
    text(0.5,4,TabDat.str,'HorizontalAlignment','Center',...
        'FontName',PF.helvetica,'FontSize',FS(8),'FontAngle','Italic')

    %-Footnote with SPM parameters (if classical inference)
    %----------------------------------------------------------------------
    line([0 1],[0.01 0.01],'LineWidth',1,'Color','r')
    if ~isempty(TabDat.ftr)
        set(gca,'DefaultTextFontName',PF.helvetica,...
            'DefaultTextInterpreter','None','DefaultTextFontSize',FS(8))

        fx = repmat([0 0.5],ceil(size(TabDat.ftr,1)/2),1);
        fy = repmat((1:ceil(size(TabDat.ftr,1)/2))',1,2);
        for i=1:size(TabDat.ftr,1)
            text(fx(i),-fy(i)*dy,sprintf(TabDat.ftr{i,1},TabDat.ftr{i,2}),...
                'UserData',TabDat.ftr{i,2},...
                'ButtonDownFcn','get(gcbo,''UserData'')');
        end
    end

    %-Characterize excursion set in terms of maxima
    % (sorted on Z values and grouped by regions)
    %======================================================================
    if isempty(TabDat.dat)
        text(0.5,y-6*dy,'no suprathreshold clusters',...
            'HorizontalAlignment','Center',...
            'FontAngle','Italic','FontWeight','Bold',...
            'FontSize',FS(16),'Color',[1,1,1]*.5);
        return
    end

    %-Table proper
    %======================================================================

    %-Column Locations
    %----------------------------------------------------------------------
    tCol = [ 0.01      0.08 ...                                %-Set
                0.15      0.24      0.33      0.39 ...            %-Cluster
                0.49      0.58      0.65      0.74      0.83 ...  %-Peak
                0.92];                                            %-XYZ

    %-Pagination variables
    %----------------------------------------------------------------------
    hPage = [];
    set(gca,'DefaultTextFontName',PF.courier,'DefaultTextFontSize',FS(7));

    %-Set-level p values {c} - do not display if reporting a single cluster
    %----------------------------------------------------------------------
    if isempty(TabDat.dat{1,1}) % Pc
        set(Hs,'Visible','off');
    end

    if TabDat.dat{1,2} > 1 % c
        h     = text(tCol(1),y,sprintf(TabDat.fmt{1},TabDat.dat{1,1}),...
                    'FontWeight','Bold', 'UserData',TabDat.dat{1,1},...
                    'ButtonDownFcn','get(gcbo,''UserData'')');
        hPage = [hPage, h];
        h     = text(tCol(2),y,sprintf(TabDat.fmt{2},TabDat.dat{1,2}),...
                    'FontWeight','Bold', 'UserData',TabDat.dat{1,2},...
                    'ButtonDownFcn','get(gcbo,''UserData'')');
        hPage = [hPage, h];
    else
        set(Hs,'Visible','off');
    end

    %-Cluster and local maxima p-values & statistics
    %----------------------------------------------------------------------
    HlistXYZ   = [];
    HlistClust = [];
    for i=1:size(TabDat.dat,1)

        %-Paginate if necessary
        %------------------------------------------------------------------
        if y < dy
            h = text(0.5,-5*dy,...
                sprintf('Page %d',spm_figure('#page',Fgraph)),...
                        'FontName',PF.helvetica,'FontAngle','Italic',...
                        'FontSize',FS(8));
            spm_figure('NewPage',[hPage,h])
            hPage = [];
            y     = y0;
        end

        %-Print cluster and maximum peak-level p values
        %------------------------------------------------------------------
        if  ~isempty(TabDat.dat{i,5}), fw = 'Bold'; else, fw = 'Normal'; end

        for k=3:11
            h = text(tCol(k),y,sprintf(TabDat.fmt{k},TabDat.dat{i,k}),...
                        'FontWeight',fw,...
                        'UserData',TabDat.dat{i,k},...
                        'ButtonDownFcn','get(gcbo,''UserData'')');
            hPage = [hPage, h];
            if k == 5
                HlistClust = [HlistClust, h];
                set(h,'UserData',struct('k',TabDat.dat{i,k},'XYZmm',TabDat.dat{i,12}));
                set(h,'ButtonDownFcn','getfield(get(gcbo,''UserData''),''k'')');
            end
        end

        % Specifically changed so it properly finds hMIPax
        %------------------------------------------------------------------
        tXYZmm = TabDat.dat{i,12};
        BDFcn  = [...
            'spm_mip_ui(''SetCoords'',get(gcbo,''UserData''),',...
                'findobj(''tag'',''hMIPax''));'];
        BDFcn = 'spm_XYZreg(''SetCoords'',get(gcbo,''UserData''),Fgraph,1);';
        h = text(tCol(12),y,sprintf(TabDat.fmt{12},tXYZmm),...
            'FontWeight',fw,...
            'Tag','ListXYZ',...
            'ButtonDownFcn',BDFcn,...
            'Interruptible','off',...
            'BusyAction','Cancel',...
            'UserData',tXYZmm);

        HlistXYZ = [HlistXYZ, h];
        hPage  = [hPage, h];
        y      = y - dy;
    end

    %-Number and register last page (if paginated)
    %----------------------------------------------------------------------
    if spm_figure('#page',Fgraph)>1
        h = text(0.5,-5*dy,sprintf('Page %d/%d',spm_figure('#page',Fgraph)*[1,1]),...
            'FontName',PF.helvetica,'FontSize',FS(8),'FontAngle','Italic');
        spm_figure('NewPage',[hPage,h])
    end
end

function print_table(F,fname)
% this is essentially a simplified spm_figure('Print',...)
    opt = 'jpg';

    %-Make print-friendly
    set(findall(F,'Type','text'),'FontUnits','normalized','FontSize',0.05);
    set(F,'PaperUnits','inches','PaperPosition',[0 0 5 4]);

    %-See if window has paging controls
    hNextPage = findall(F,'Tag','NextPage');
    hPrevPage = findall(F,'Tag','PrevPage');
    hPageNo   = findall(F,'Tag','PageNo');
    iPaged    = ~isempty(hNextPage);

    %-Print
    if ~iPaged
        spm_print(fname,F,opt);
    else
        hPg    = get(hNextPage,'UserData');
        Cpage  = get(hPageNo,  'UserData');
        nPages = size(hPg,1);

        set([hNextPage,hPrevPage,hPageNo],'Visible','off');
        if Cpage~=1
            set(hPg{Cpage,1},'Visible','off');
        end
        for p = 1:nPages
            set(hPg{p,1},'Visible','on');
            spm_print(fname,F,opt);
            set(hPg{p,1},'Visible','off');
        end
        set(hPg{Cpage,1},'Visible','on');
        set([hNextPage,hPrevPage,hPageNo],'Visible','on');
    end
end

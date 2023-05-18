% FSL-like overlay + SPM orthview video for registration diagnostics
%
% registrationCheck(rap,domain,indices,background,output1,...[,'mode','seperate'|'combined'][,'prefix',pfx])
%
% domain and indices MUST correspond to the stream input at the lower domain
% images (backgroud and output(s)) can be:
%   - stream
%   - path to image
% background MUST be single-volume
% output(s) CAN be a multi-volume stream,in which case all volumes are reported

function registrationCheck(rap,domain,indices,background,varargin)

    visFig = 'on';
    if rap.internal.isdeployed, visFig = 'off'; end

    % Parse
    output = varargin;
    mode = 'separate';
    if any(strcmp(output, 'mode'))
        iPar = find(strcmp(output, 'mode'));
        mode = output{iPar+1};
        output(iPar:iPar+1) = [];
    end
    pfx = '';
    if any(strcmp(output, 'prefix'))
        iPar = find(strcmp(output, 'prefix'));
        pfx = output{iPar+1};
        output(iPar:iPar+1) = [];
    end

    % backgroud
    if ~exist(background,'file') && ~exist(spm_file(background,'number',''),'file'), background = getFileByStream(rap,domain,indices,background,'checkHash',false); end
    toExcl = [];
    for o = 1:numel(output)
        testO = strsplit(output{o},','); testO = testO{1}; % volume might be selected
        if ~exist(testO,'file'), output{o} = getFileByStream(rap,domain,indices,output{o},'streamType','output','checkHash',false); end
        try
            spm_vol(output{o});
        catch
            logging.warning('%s not recognised as image --> skipping',output{o});
            toExcl(end+1) = o;
        end
    end
    output(toExcl) = [];
    for oInd = 1:numel(output)
        if iscell(output{oInd}), output{oInd} = output{oInd}{1}; end
    end

    diag = getSetting(rap,'diagnostics');
    if ~isempty(diag) && ((~isstruct(diag) && ~diag) || (isstruct(diag) && ~diag.streamindex))
        logging.info('Diagnostics is disabled. Check rap.tasksettings.<module>.diagnostics!');
    else
        % Resize slice display for optimal fit
        fig = spm_figure('GetWin','Graphics');
        set(fig,'visible',visFig);
        windowSize = get(0,'ScreenSize');
        windowSize(4) = windowSize(4) - windowSize(2) - 50 - 50; % 50 for system menu and statusbar, 50 for figure menu
        windowSize(2) = 50;
        set(fig,'Position', windowSize)

        global st;
        switch mode
            case 'separate'
                spm_check_registration(char([background,output]));

                % Contours
                switch spm('ver')
                    case {'SPM12b' 'SPM12'}
                        for v = 1:2 % show contours only of the background and the first output
                            [h, f] = getContextmenuCallback(st.vols{v}.ax{1}.ax,'Contour|Display|all but');
                            f(h,[]);
                            hM = getContextmenuCallback(st.vols{v}.ax{1}.ax,'Contour');
                            UDc = get(hM,'UserData'); UDc.nblines = 1; set(hM,'UserData',UDc); % narrow
                            spm_ov_contour('redraw',v,{});
                        end
                end
            case 'combined'
                LUT = distinguishable_colors(numel(output),[0 0 0; 0.5 0.5 0.5; 1 1 1]);
                spm_check_registration(background);
                for o = 1:numel(output)
                    spm_orthviews('addcolouredimage',1,output{o},LUT(o,:));
                end
                spm_orthviews('Redraw');
        end

        % Intialise slices
        for v = 1:numel(st.vols)
            if isempty(st.vols{v}), break; end
            bb(:,:,v) = spm_get_bbox(st.vols{v});
        end
        nVols = v-1;

        step = max([1, rap.options.diagnosticvideoframestep]);
        % slices{1} = -85:1:85; % sagittal
        % slices{2} = -120:1:90; % coronal
        % slices{3} = -70:1:90; % axial
        slices{1} = max(bb(1,1,:)):step:min(bb(2,1,:)); % sagittal
        slices{2} = max(bb(1,2,:)):step:min(bb(2,2,:)); % coronal
        slices{3} = max(bb(1,3,:)):step:min(bb(2,3,:)); % axial
        nMin = min(cellfun(@numel, slices));
        for a = 1:3
            stepAdj = (slices{a}(end)-slices{a}(1))/(nMin-1);
            slicesToVideo(a,:) = round(slices{a}(1):stepAdj:slices{a}(end));
        end
        slicesIndToSummary = [round(size(slicesToVideo,2)/4) round(size(slicesToVideo,2)/2) round(3*size(slicesToVideo,2)/4)];
        slicesSummary = repmat({cell(1,3)},1,nVols);

        % Orthoview summary
        % - collect frames
        for sInd = slicesIndToSummary
            spm_orthviews('reposition', slicesToVideo(:,sInd));
            spm_orthviews('Xhairs','off');
            for v = 1:nVols
                for a = 1:3
                    fr = getframe(st.vols{v}.ax{a}.ax);
                    slicesSummary{v}{a} = horzcat(slicesSummary{v}{a}, fr.cdata);
                end
            end
            spm_orthviews('Xhairs','on');
        end

        % - create image
        for v = 1:numel(slicesSummary)
            slicesFilename = fullfile(getPathByDomain(rap,domain,indices),sprintf('diagnostic_%s%s_%s.jpg',rap.tasklist.currenttask.name,pfx,spm_file(st.vols{v}.fname,'basename')));
            img = slicesSummary{v}{3};
            img(1:size(slicesSummary{v}{2},1),end+1:end+size(slicesSummary{v}{2},2),:) = slicesSummary{v}{2};
            img(1:size(slicesSummary{v}{1},1),end+1:end+size(slicesSummary{v}{1},2),:) = slicesSummary{v}{1};
            f = figure('visible',visFig);
            set(f,'Position',[1 1 size(img,2) size(img,1)],'PaperPositionMode','auto','InvertHardCopy','off');
            imshow(img,'Border','tight');
            print(f,'-djpeg','-r150',slicesFilename);
            close(f);
        end

        % Video
        if rap.options.diagnosticvideoframestep == 0, logging.info('Diagnostic videos disabled. Check rap.options.diagnosticvideos!');
        else
            movieFilename = fullfile(getPathByDomain(rap,domain,indices),sprintf('diagnostic_%s%s_%s.mp4',rap.tasklist.currenttask.name,pfx,spm_file(st.vols{v}.fname,'basename')));
            if exist(movieFilename,'file'), delete(movieFilename);  end
            video = VideoWriter(movieFilename); video.open(); % TODOD: reduce FrameRate (currently not supported in OCTAVE - 12/02/23)

            for d = 1:size(slicesToVideo,2)
                spm_orthviews('reposition', slicesToVideo(:,d));
                video.writeVideo(getframe(fig));
            end

            video.close();
        end

        close(spm_figure('GetWin','Graphics'));
    end

end

function [h f] = getContextmenuCallback(h,menuPath)
    h = get(h,'uicontextmenu');
    menuPath = strsplit(menuPath,'|');

    for i = 1:numel(menuPath)
        ch = get(h,'children');
        l = get(ch,'label');
        h = ch(contains(l,menuPath{i}));
    end

    f = get(h,'callback');
end

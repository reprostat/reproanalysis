function rap = reproa_segment(rap, command, subj)

    switch command
        case 'report'
            reportStore = sprintf('sub%d',subj);
            addReport(rap,reportStore,'<h4>Separation of tissues</h4>');
            rap = addReportMedia(rap,reportStore,spm_select('FPList',getPathByDomain(rap,'subject',subj),['^diagnostic_' mfilename '.*_histogram\.jpg$']),'displayFileName',false);

            addReport(rap,reportStore,'<h4>Segmentation</h4>');
            rap = addReportMedia(rap,reportStore,spm_select('FPList',getPathByDomain(rap,'subject',subj),['^diagnostic_' mfilename '.*_' spm_file(char(getFileByStream(rap,'subject',subj,'structural','checkHash',false)),'basename') '.*\.jpg$']),'displayFileName',false);

            addReport(rap,reportStore,'<h4>Segmentation and normalisation</h4>');
            rap = addReportMedia(rap,reportStore,spm_select('FPList',getPathByDomain(rap,'subject',subj),['^diagnostic_' mfilename '.*T1\.jpg$']),'displayFileName',false);

        case 'doit'
            global reproacache
            SPM = reproacache('toolbox.spm');
            SPM.reload(true); % update defaults

            %% Options
            cfgBiascorrection = getSetting(rap,'biascorrection');

            cfgSegmentation = getSetting(rap,'segmentation');
            if ~exist(cfgSegmentation.tpm, 'file'), logging.error('Specified TPM %s not found.', cfgSegmentation.tpm); end
            logging.info('Segmenting using TPMs from %s.', cfgSegmentation.tpm);
            cfgSegmentation.native = [1 1]; % [native DARTEL_imported]
            cfgSegmentation.warped = [1 1]; % normalised [modulated unmodulated]

            cfgNormalisation = getSetting(rap,'normalisation');
            if ~isempty(cfgNormalisation.affreg) && isnumeric(cfgNormalisation.affreg)
                initialAffine = cfgNormalisation.affreg;
                cfgNormalisation.affreg = 'mni';

                initialAffine(end+1:6) = 0; initialAffine = [initialAffine  1 1 1   0 0 0];
                initialAffine = spm_matrix(initialAffine);
            end
            switch spm('ver')
                case 'SPM8'
                    cfgNormalisation.reg = 4;
                    cfgNormalisation.bb = {NaN(2,3)};
                case {'SPM12b' 'SPM12'}
                    cfgNormalisation.reg = [0 1e-3 0.5 0.05 0.2];
                    cfgNormalisation.bb = NaN(2,3);
            end

            %% Required functions
            if ~exist('spm_preproc_run', 'file')
                switch spm('ver')
                    case {'SPM12' 'SPM12b'}
                        logging.error('spm_preproc_run is not found, SPM12 may not be installed properly');
                    case 'SPM8'
                        logging.warning('spm_preproc_run is not found, may be in Seg toolbox (SPM8)');
                        % try adding a likely location
                        addpath(fullfile(spm('dir'),'toolbox','Seg'))
                    otherwise
                        logging.error('%s requires SPM8 or later.', mfilename);
                end
            end
            if ~exist('spm_preproc_run', 'file'), logging.error('spm_preproc_run is not found'); end

            if ~exist('optimNn', 'file')
                logging.warning('optimNn is not found, may be in DARTEL toolbox');
                addpath(fullfile(spm('dir'),'toolbox','DARTEL'))
            end
            if ~exist('optimNn', 'file'), logging.error('optimNn is not found'); end

            %% Images (multichan)
            img = cellfun(@(sn) getFileByStream(rap,'subject',subj,sn),getStreamByName(rap,'streamList'));
            % Check orientation
            [s, w] = spm_check_orientations(cell2mat(spm_vol(img)),false);
            if ~s
                logging.warning([strjoin(cellstr(w),'\n') '\n\t -> Reslicing %s'],img{2});
                spm_reslice(img,struct('interp',3,'which',[1 0],'prefix','r'));
                img{2} = spm_file(img{2},'prefix','r');
            end

            %% Segmentation
            % create job
            for k = 1:numel(cfgSegmentation.ngaus)
                job.tissue(k) = cfgSegmentation;
                job.tissue(k).tpm = {spm_file(job.tissue(k).tpm,'number',[',' num2str(k)])};
                job.tissue(k).ngaus = job.tissue(k).ngaus(k);
            end

            for c = 1:numel(img)
                ch = structUpdate(cfgBiascorrection,cfgSegmentation,'Mode','extend');
                ch.vols  = img(c);
                job.channel(c) = ch;
            end

            job.warp = cfgNormalisation;
            if numel(job.channel) > 1, logging.warning('Multi-channel segmentation might take up to a couple of hours!'); end

            tic
            logging.info('Starting to segment');
            spm_preproc_run(job);
            logging.info('\tDone in %.1f minutes.', toc/60);

            %% Prepare outputs
            % deformation fields (only one - named after the first channel)
            img1 = img{1};
            normFieldFn = spm_file(img1,'prefix','y_');
            invFieldFn = spm_file(img1,'prefix','iy_');
            segestFn = spm_file(img1,'suffix','_seg8','ext','mat');
            localPath = fullfile(getPathByDomain(rap,'subject',subj),rap.directoryconventions.structdirname);

            % combination
            if ~isempty(getSetting(rap,'writecombined'))
                logging.info('Mask outputs with segmentation(s)');
                for c = 1:numel(img)
                    w = getSetting(rap,'writecombined');
                    V = spm_vol(img{c});
                    mask = false(V.dim);
                    for t = 1:numel(w)
                        if ~w(t), continue; end
                        fname = spm_file(img1,'prefix',sprintf('c%d',t));
                        tmask = spm_read_vols(spm_vol(fname));
                        if w(t) > 0
                            logging.info('%s >= %1.3f', spm_file(fname,'basename'), w(t));
                            mask = mask | (tmask >= w(t));
                        else
                            logging.info('%s <= %1.3f', spm_file(fname,'basename'), abs(w(t)));
                            mask = mask | (tmask <= abs(w(t)));
                        end
                    end
                    Y = spm_read_vols(V).*mask;
                    V.fname = spm_file(V.fname,'prefix','c');
                    spm_write_vol(V,Y);
                    img{c} = V.fname;
                end
            end

            % normalise inputs
            cfgWrite = getSetting(rap,'writenormalised');
            if ~strcmp(cfgWrite.method,'none')
                for c = 1:numel(img)
                    logging.info('Applying normalisation field on to %s', spm_file(img{c},'basename'));
                    clear djob ojob
                    ojob.ofname = '';
                    ojob.fnames{1} = img{c};
                    ojob.savedir.saveusr{1} = localPath;
                    ojob.interp = 1; % trilinear (hard-coded)
                    switch spm('ver')
                        case 'SPM8'
                            spm_func_def = @spm_defs;
                            djob = ojob;
                            djob.comp{1}.def{1} = normFieldFn;
                        case {'SPM12b' 'SPM12'}
                            spm_func_def = @spm_deformations;
                            ojob.mask = 0;
                            ojob.fwhm = cfgWrite.fwhm;
                            djob.comp{1}.def{1} = normFieldFn;
                            djob.out{1}.savedef = ojob;
                            djob.out{2}.(cfgWrite.method) = ojob;
                            djob.out{2}.(cfgWrite.method).fov.bbvox.bb = cfgNormalisation.bb;
                            djob.out{2}.(cfgWrite.method).fov.bbvox.vox = cfgNormalisation.vox;
                            djob.out{2}.(cfgWrite.method).preserve = cfgWrite.preserve;
                        otherwise
                            logging.error('%s requires SPM8 or later', mfilename);
                    end
                    spm_func_def(djob);
                end
            end

            %% Describe outputs
            global defaults
            putFileByStream(rap,'subject',subj,'segmentation_estimates',segestFn);

            descStr = {'GM' 'WM' 'CSF' 'Bone' 'Soft' 'OOH'};
            descType = {'' 'native_segmentations';...
                       'r' 'dartelimported_segmentations';...
                       defaults.normalise.write.prefix 'normaliseddensity_segmentations';...
                       ['m' defaults.normalise.write.prefix] 'normalisedvolume_segmentations' };
            for t = 1:size(descType,1)
                files = cellstr(spm_select('FPList',localPath,['^' descType{t,1} 'c[0-9]' spm_file(img1,'filename') '$']));
                cStruct = reshape([descStr; files'],1,[]);
                putFileByStream(rap,'subject',subj,descType{t,2},struct(cStruct{:}));
            end

            pfx = '';
            if ~strcmp(cfgWrite.method,'none')
                pfx = [defaults.normalise.write.prefix pfx];
                if strcmp(cfgWrite.method,'push') && cfgWrite.preserve, pfx = ['m' pfx]; end
                if sum(cfgWrite.fwhm.^2)~=0, pfx = ['s' pfx]; end
            end

            if ~isempty(getSetting(rap,'writecombined')) || ~strcmp(cfgWrite.method,'none')
                for c = 1:numel(img)
                    putFileByStream(rap,'subject',subj,...
                        rap.tasklist.currenttask.inputstreams(c).name,...
                        spm_file(img{c},'prefix',pfx));
                end
            end

            putFileByStream(rap,'subject',subj,'forward_deformationfield', normFieldFn);
            putFileByStream(rap,'subject',subj,'inverse_deformationfield', invFieldFn);

            %% Diagnostics
            diagnostics(rap,subj);

        case 'checkrequirements'
            % Template
            tpm = getSetting(rap,'segmentation.tpm');
            if ~exist(tpm, 'file')
                logging.warning('Specified TPM %s not found.\n\tTrying SPM12 default.', tpm);
                tpm = fullfile(spm('dir'),'tpm','TPM.nii');
            end
            if ~exist(tpm, 'file')
                logging.warning('Specified TPM %s not found.\n\tTrying SPM8 default.', tpm);
                tpm = fullfile(spm('dir'),'toolbox','Seg','TPM.nii');
            end
            if ~exist(tpm, 'file'), logging.error('Specified TPM %s not found.', tpm); end
            rap.tasksettings.(regexp(rap.tasklist.currenttask.name,'.*(?=_[0-9]{5})','match','once'))(rap.tasklist.currenttask.index).segmentation.tpm = tpm;

            % Match output to inputs
            xml = readModule([regexp(rap.tasklist.currenttask.name,'.*(?=_0)','match','once') '.xml']);
            for input = {xml.inputstreams.name}
                if ~hasStream(rap,input{1}) && any(strcmp({rap.tasklist.currenttask.outputstreams.name},input{1}))
                    rap = renameStream(rap,rap.tasklist.currenttask.name,'output',input{1},[]);
                    logging.info('REMOVED: %s output stream due to no matching input: %s', rap.tasklist.currenttask.name,input{1});
                end
            end

            % Remove "input as output" stream not to be created
            if strcmp(getSetting(rap,'writenormalised.method'),'none') && isempty(getSetting(rap,'writecombined'))
                for input = {rap.tasklist.currenttask.inputstreams.name}
                    if any(strcmp({rap.tasklist.currenttask.outputstreams.name},input{1}))
                        rap = renameStream(rap,rap.tasklist.currenttask.name,'output',input{1},[]);
                        logging.info('REMOVED: %s output stream: %s', rap.tasklist.currenttask.name,input{1});
                    end
                end
            end
    end
end

function diagnostics(rap,subj)
    Simg = getFileByStream(rap,'subject',subj,'structural','streamType','input');
    Timg = rap.directoryconventions.T1template;
    if ~exist(Timg,'file'), Timg = fullfile(spm('dir'), Timg); end
    if ~exist(Timg,'file'), logging.error('Couldn''t find template T1 image %s.', Timg); end
    Timg = which(Timg);

    nativeSeg = getFileByStream(rap,'subject',subj,'native_segmentations','content',{'GM' 'WM' 'CSF'});
    normSeg = getFileByStream(rap,'subject',subj,'normaliseddensity_segmentations','content',{'GM' 'WM'});
    nSeg = numel(fieldnames(nativeSeg));
    [~, indGMWM] = ismember({'GM' 'WM'},fieldnames(nativeSeg));

    % Only for GM WM
    registrationCheck(rap,'subject',subj,Simg{1},nativeSeg.GM{1},nativeSeg.WM{1},'mode','combined');
    registrationCheck(rap,'subject',subj,Timg,normSeg.GM{1},normSeg.WM{1},'mode','combined');

    %% Another diagnostic image, looking at how well the segmentation worked...
    Pthresh = 0.95;
    visFig = 'on';
    if ~isOctave() && rap.internal.isdeployed, visFig = 'off'; end

    YS = spm_read_vols(spm_vol(Simg{1}));
    YSeg = cellfun(@(seg) YS(spm_read_vols(spm_vol(nativeSeg.(seg){1}))>=Pthresh), fieldnames(nativeSeg),'UniformOutput',false);
    f = figure('visible',visFig); hold on; LUT = distinguishable_colors(nSeg,[0 0 0; 0.5 0.5 0.5; 1 1 1]);
    arrayfun(@(s) hist(YSeg{s}, 100, "facecolor", LUT(s,:), "edgecolor", "none"), 1:nSeg);

    [~, p, ~, stats] = ttest2(YSeg{indGMWM});
    title(sprintf('GM vs WM... T(%d)=%0.1f, p=%1.3f', stats.df, stats.tstat, p))

    print(f,'-djpeg','-r150',...
        fullfile(getPathByDomain(rap,'subject',subj),['diagnostic_' rap.tasklist.currenttask.name '_histogram.jpg']));
    close(f);
end

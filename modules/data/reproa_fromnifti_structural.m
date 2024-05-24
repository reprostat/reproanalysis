function rap = reproa_fromnifti_structural(rap,command,subj)

    switch command
        case 'doit'
            global reproacache;
            global defaults
            flagsCoreg = defaults.coreg.estimate;
            flagsCoreg.cost_fun = 'ecc';
            flagsReslice = defaults.realign.write;
            flagsReslice.which = [1 0];

            allseries = getSeries(rap.acqdetails.subjects(subj).structural);
            allstreams = {rap.tasklist.currenttask.outputstreams.name}; allstreams(lookFor(allstreams,'header')) = [];
            sfxs = strsplit(getSetting(rap,'sfxformodality'),':');

            for m = 1:numel(sfxs)
                stream = allstreams{m};

                doAverage = false;

                % Select
                series = allseries(cellfun(@(x) ~isempty(x), strfind({allseries.fname},sfxs{m})));
                switch numel(series)
                    case 0
                        logging.warning(['No ' stream ' image found']);
                        continue;
                    case 1
                    otherwise
                        switch rap.options.(['autoidentify' stream])
                            case 'none'
                                logging.info([stream ' is skipped (check rap.options.autoidentify' stream ')']);
                                continue;
                            case 'choosefirst'
                                series = series(1);
                            case 'chooselast'
                                series = series(end);
                            case 'multiple'
                                % keep all
                            case 'average'
                                doAverage = true;
                        end
                end

                localPath = fullfile(getPathByDomain(rap,'subject',subj),rap.directoryconventions.structdirname);
                dirMake(localPath);
                Ys = 0;
                for s = 1:numel(series)
                    niftiFile = series(s).fname;
                    hdrFile = series(s).hdr;

                    %% Image
                    if ~exist(niftiFile,'file')
                        niftiFile = '';
                        for niftisearchpth = cellfun(@(d) findData(rap,'mri',d), rap.acqdetails.subjects(subj).mridata,'UniformOutput',false);
                            niftiFile = fullfile(niftisearchpth{1},niftiFile);
                            if exist(niftiFile,'file'), break; end
                        end
                        if isempty(niftiFile), logging.error(['Image ' niftiFile ' not found']); end
                    end

                    doUncompress = false;
                    if strcmp(spm_file(niftiFile,'ext'),'gz')
                        doUncompress = true;
                        gunzip(niftiFile,rap.internal.tempdir);
                        niftiFile = spm_file(niftiFile,'path',rap.internal.tempdir,'ext','');
                    end

                    if doAverage
                        % Create copy to avoid overwriting raw data
                        if ~doUncompress % images are already copied during uncompression
                            copyfile(niftiFile,rap.internal.tempdir);
                            niftiFile = spm_file(niftiFile,'path',rap.internal.tempdir);
                        end

                        sV = spm_vol(niftiFile);
                        V(s) = sV(1);
                        if s > 1 % coregister all subsequent images to the first
                            x = spm_coreg(V(1),V(s),flagsCoreg);
                            spm_get_space(V(s).fname, spm_matrix(x)\spm_get_space(V(s).fname));
                            V(s) = spm_vol(V(s).fname); % update
                        end
                    else
                        copyfile(niftiFile,localPath);
                        fn{s} = spm_file(niftiFile,'path',localPath);
                    end

                    %% header
                    header{s} = [];
                    if ~isempty(hdrFile)
                        if ischar(hdrFile) && strcmp(spm_file(hdrFile,'ext'),'mat') % already processed by reproa
                            load(hdrFile,'header');
                        else
                            if isstruct(hdrFile)
                                header{s} = hdrFile;
                            elseif ischar(hdrFile) && strcmp(spm_file(hdrFile,'ext'),'json') % BIDS
                                header{s} = jsonread(hdrFile);
                            end
                            % convert timings to ms (consistent with DICOM)
                            for f = fieldnames(header{s})'
                                if strfind(f{1},'Time'), header{s}.(f{1}) = header{s}.(f{1})*1000; end
                            end
                            if isfield(header{s},'RepetitionTime'), header{s}.volumeTR = header{s}.RepetitionTime/1000; end
                            if isfield(header{s},'EchoTime'), header{s}.volumeTE = header{s}.EchoTime/1000; end
                        end
                    end
                    if isempty(header{s}), logging.warning('No header found!'); end
                end

                if doAverage
                    % reslice
                    spm_reslice(V,flagsReslice);
                    V(2:end) = cellfun(@spm_vol, spm_file({V(2:end).fname},'prefix',flagsReslice.prefix));

                    % average and mask
                    Y = spm_read_vols(V);
                    mY = Y(:,:,:,1) == 0;
                    Y = mean(Y,4);
                    Y(mY) = 0;

                    % save
                    V = V(1); V.fname = spm_file(V.fname,'path',localPath,'prefix','mean'); V.descrip = 'average';
                    spm_write_vol(V,Y);
                    fn = V.fname;
                    header = header(1);
                end

                if ~all(cellfun(@isempty,header))
                    hdrfn = fullfile(localPath,[stream '_header.mat']);
                    if isOctave
                        save('-mat-binary',hdrfn,'header');
                    else
                        save(hdrfn,'header');
                    end
                    putFileByStream(rap,'subject',subj,[stream '_header'],hdrfn);
                end

                if getSetting(rap,'reorienttotemplate')
                    if lookFor(sfxs{m},'t1','ignoreCase',true), bTimg = 'T1';
                    elseif lookFor(sfxs{m},'t2','ignoreCase',true), bTimg = 'T2';
                    elseif lookFor(sfxs{m},'pd','ignoreCase',true), bTimg = 'PD';
                    elseif lookFor(sfxs{m},'flair','ignoreCase',true), bTimg = 'PD';
                    else
                        logging.warning('reorient to template is not implemented for %s images',sfxs{m});
                    end
                    sTimg = spm_file(rap.directoryconventions.SPMT1,'basename',bTimg);
                    if ~exist(sTimg,'file'), sTimg = fullfile(spm('dir'), sTimg); end
                    if ~exist(sTimg,'file'), logging.error('Couldn''t find template image %s.', sTimg); end
                    sTimg = which(sTimg);

                    % Coregister
                    x = spm_coreg(sTimg, fn, flagsCoreg);
                    M = spm_matrix(x);

                    % Set the new space for the structural
                    spm_get_space(fn, M\spm_get_space(fn));
                end

                putFileByStream(rap,'subject',subj,stream,fn);

            end

        case 'checkrequirements'
            allseries = getSeries(rap.acqdetails.subjects(subj).structural);
            allstreams = {rap.tasklist.currenttask.outputstreams.name}; allstreams(lookFor(allstreams,'header')) = [];
            sfxs = strsplit(getSetting(rap,'sfxformodality'),':');

            % correspond data
            noData = cellfun(@(s) ~any(lookFor({allseries.fname},s)), sfxs);
            rap.tasksettings.(regexp(rap.tasklist.currenttask.name,'.*(?=_[0-9]{5})','match','once'))(rap.tasklist.currenttask.index).sfxformodality = strjoin(sfxs(~noData),':');

            % correspond outputstreams
            streamSFX = sfxs(~noData); streamSFX{strcmp(streamSFX,'T1w')} = 'structural'; streamSFX = lower(regexprep(streamSFX,'w$',''));
            noSFX = cellfun(@(s) ~any(lookFor(streamSFX,s)), allstreams);

            for s = find(noSFX)
                rap = renameStream(rap,rap.tasklist.currenttask.name,'output',allstreams{s},'');
                logging.info('REMOVED: %s output stream: %s', rap.tasklist.currenttask.name,allstreams{s});
                rap = renameStream(rap,rap.tasklist.currenttask.name,'output',[allstreams{s} '_header'],'');
                logging.info('REMOVED: %s output stream: %s', rap.tasklist.currenttask.name,[allstreams{s} '_header']);
            end
    end
end

function allseries = getSeries(structural)
    allseries = horzcat(structural{:}); % uniform input assumed
    if isstruct(allseries{1})
        allseries = cell2mat(allseries);
    elseif iscellstr(allseries)
        allseries = cellfun(@(x) struct('fname',x,'hdr',''), allseries);
    else
        help aas_addsubject
        logging.error(['rap.acqdetails.subjects.structural has a wrong format\n\n' help('addSubject')]);
    end
end

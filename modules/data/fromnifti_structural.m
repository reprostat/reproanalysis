% AA module - structural from NIFTI

function rap = fromnifti_structural(rap,command,subj)

    switch command
        case 'doit'
            allseries = getSeries(rap.acqdetails.subjects(subj).structural);
            allstreams = {rap.tasklist.currenttask.outputstreams.name}; allstreams(contains(allstreams,'header')) = [];
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
                        tmpDir = tempdir;
                        gunzip(niftiFile,tmpDir);
                        niftiFile = spm_file(niftiFile,'path',tmpDir,'ext','');
                    end

                    V(s) = spm_vol(niftiFile);
                    Y = spm_read_vols(V(s));

                    if doUncompress, delete(niftiFile); end

                    fn{s} = spm_file(niftiFile,'path',localPath,'suffix','_0001');
                    V(s).fname = deblank(fn{s});
                    V(s).n=[1 1];

                    if doAverage
                        Ys = Ys + Y/numel(series);
                    else
                        spm_write_vol(V(s),Y);
                    end

                    %% header
                    header{s} = [];
                    if ~isempty(hdrFile)
                        if ischar(hdrFile) && strcmp(spm_file(hdrFile,'ext'),'mat') % already processed by reproa
                            tmp = load(hdrFile); header{s} = tmp.header;
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
                    fn = fn{1};
                    V = V(1);
                    V.fname = fn;
                    spm_write_vol(V,Ys);
                    header = header(1);
                end

                putFileByStream(rap,'subject',subj,stream,fn);

                if ~all(cellfun(@isempty,header))
                    hdrfn = fullfile(localPath,[stream '_header.mat']);
                    if isOctave
                        save('-mat-binary',hdrfn,'header');
                    else
                        save(hdrfn,'header');
                    end
                    putFileByStream(rap,'subject',subj,[stream '_header'],hdrfn);
                end
            end
        case 'checkrequirements'
            allseries = getSeries(rap.acqdetails.subjects(subj).structural);
            allstreams = {rap.tasklist.currenttask.outputstreams.name}; allstreams(contains(allstreams,'header')) = [];
            sfxs = strsplit(getSetting(rap,'sfxformodality'),':');
            if numel(sfxs) ~= numel(allstreams), logging.error('streams and suffices do not match'); end
            noData = cellfun(@(s) ~any(contains({allseries.fname},s)), sfxs);
            rap.tasksettings.fromnifti_structural.sfxformodality = strjoin(sfxs(~noData),':');
            for s = find(noData)
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

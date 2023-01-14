% AA module - structural from NIFTI

function rap = fromnifti_structural(rap,command,subj)

doAverage = false;

switch command
    case 'report'
    case 'doit'
        allseries = horzcat(rap.acqdetails.subjects(subj).structural{:}); % uniform input assumed
        if isstruct(allseries{1})
            allseries = cell2mat(allseries);
        elseif iscellstr(allseries)
            allseries = cellfun(@(x) struct('fname',x,'hdr',''), allseries);
        else
            help aas_addsubject
            logging.error('rap.acqdetails.subjects.structural has a wrong format');
        end
        allstreams = rap.tasklist.currenttask.outputstreams; allstreams(contains({allstreams.name},'header')) = [];
        sfxs = strsplit(getSetting(rap,'sfxformodality'),':');

        for m = 1:numel(sfxs)
            stream = allstreams(m).name;

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

            localpath = fullfile(getPathByDomain(rap,'subject',subj),rap.directoryconventions.structdirname);
            dirMake(localpath);
            Ys = 0;
            for s = 1:numel(series)
                niftifile = series(s).fname;
                hdrfile = series(s).hdr;

                %% Image
                if ~exist(niftifile,'file')
                    niftisearchpth = findvol(rap,'mri',rap.acqdetails.subjects(subj).mridata);
                    if ~isempty(niftisearchpth)
                        niftifile = fullfile(niftisearchpth,niftifile);
                        if ~exist(niftifile,'file'), logging.error(['Image ' niftifile ' not found']); end
                    end
                end

                V(s) = spm_vol(niftifile);
                Y = spm_read_vols(V(s));

                fn{s} = spm_file(niftifile,'path',localpath,'suffix','_0001');
                if strcmp(spm_file(fn{s},'ext'),'gz'), fn{s} = spm_file(fn{s},'ext',''); end
                V(s).fname=deblank(fn{s});
                V(s).n=[1 1];

                if doAverage
                    Ys = Ys + Y/numel(series);
                else
                    spm_write_vol(V(s),Y);
                end

                %% header
                if ~isempty(hdrfile)
                    if isstruct(hdrfile)
                        dcmhdr = hdrfile;
                    else
                        switch spm_file(hdrfile,'ext')
                            case 'mat'
                                dcmhdr = load(hdrfile,'dcmhdr');
                            case 'json'
                                dcmhdr = jsonread(hdrfile);
                                % convert timings to ms (DICOM default)
                                for f = fieldnames(hdrfile)'
                                    if strfind(f{1},'Time'), dcmhdr{s}.(f{1}) = dcmhdr.(f{1})*1000; end
                                end
                                if isfield(dcmhdr{s},'RepetitionTime'), dcmhdr{s}.volumeTR = dcmhdr{s}.RepetitionTime/1000; end
                                if isfield(dcmhdr{s},'EchoTime'), dcmhdr{s}.volumeTE = dcmhdr{s}.EchoTime/1000; end
                        end
                    end
                else
                    logging.warning('No header provided!');
                end
            end

            if doAverage
                fn = fn{1};
                V = V(1);
                V.fname = fn;
                spm_write_vol(V,Ys);
                dcmhdr = dcmhdr(1);
            end

            rap = putFileByStream(rap,'subject',subj,stream,fn);

            if exist('dcmhdr','var')
                dcmhdrfn = fullfile(localpath,[stream '_header.mat']);
                save(dcmhdrfn,'dcmhdr');
                rap = putFileByStream(rap,'subject',subj,[stream '_header'],dcmhdrfn);
            end

            % remove variable to avoid writing wrong header to subsequent sfxs
            clear dcmhdr
        end
    case 'checkrequirements'

end

% fMRI from NIFTI

function rap = fromnifti_fmri(rap,command,subj,run)

switch command
    case 'doit'
        %% Init
        if isstruct(rap.tasklist.currenttask.settings.numdummies)
            numdummies = getSetting(rap,'numdummies','fmrirun',[subj run]);
        else
            numdummies = getSetting(rap,'numdummies');
        end

        %% Select
        series = horzcat(rap.acqdetails.subjects(subj).fmriseries{:});
        if ~iscell(series) ...
                || (~isstruct(series{run}) ... % hdr+fname
                && ~ischar(series{run}) ... % fname
                && ~iscell(series{run})) % fname (4D)
            logging.error(['Was expecting list of struct(s) of fname+hdr or fname in cell array\n\n' help('addSubject')]);
        end
        series = series{run};

        %% Process
        runpth = getPathByDomain(rap,'fmrirun',[subj,run]);

        % Files
        headerFn ='';
        imageFn = series;
        if isstruct(imageFn)
            headerFn = imageFn.hdr;
            imageFn = imageFn.fname;
        end
        headerFile = headerFn;
        niftiFile = imageFn;
        if ~iscell(niftiFile), niftiFile = {niftiFile}; end % 4D-NIFTI
        if ~exist(niftiFile{1},'file') % try path realtive to the subject's dir
            niftisearchpth = findvol(rap,'mri',rap.acqdetails.subjects(subj).mridata);
            if ~isempty(niftisearchpth)
                niftiFile = fullfile(niftisearchpth,niftiFile);
                if ~exist(niftiFile{1},'file'), logging.error(['Image ' niftiFile{1} ' not found']); end
                if ~isempty(headerFn), headerFile = fullfile(niftisearchpth,headerFn); end
            end
        end

        % Header
        header = {};
        if ischar(headerFile) && strcmp(spm_file(headerFile,'ext'),'mat') % already processed by reproa
            load(headerFile,'header');
        else
            if isstruct(headerFile)
                header{1} = headerFile;
            elseif ischar(headerFile) && strcmp(spm_file(headerFile,'ext'),'json') % BIDS
                header{1} = jsonread(headerFile);
            end

            % Check fields and convert timings to ms (consistent with DICOM)
            if ~isfield(header{1},'RepetitionTime'), logging.error('RepetitionTime is required for fMRI'); end
            header{1}.RepetitionTime = header{1}.RepetitionTime*1000;
            for f = {'EchoTime' 'SliceTiming' 'EffectiveEchoSpacing'} % optional
                if isfield(header{1},f{1}), header{1}.(f{1}) = header{1}.(f{1})*1000;
                else, header{1}.(f{1}) = [];
                end
            end
            if isempty(header{1}.EchoTime), logging.warning('EchoTime is not provided -> calculating CNR is not possible'); end
            if isempty(header{1}.SliceTiming), logging.warning('SliceTiming is not provided -> slicetime-correction is not possible'); end
            if isempty(header{1}.EffectiveEchoSpacing), logging.warning('EffectiveEchoSpacing is not provided -> distortion-correction is not possible'); end

            header{1}.volumeTR = header{1}.RepetitionTime/1000;
            header{1}.volumeTE = header{1}.EchoTime/1000;
            header{1}.slicetimes = header{1}.SliceTiming/1000;
            [~, header{1}.sliceorder] = sort(header{1}.slicetimes);
            header{1}.echospacing = header{1}.EffectiveEchoSpacing/1000;
        end
        if isempty(header), logging.warning('No header provided!'); end

        % Image
        finalepis={};
        V = spm_vol(niftiFile);
        if iscell(V), V = cell2mat(V); end
        if strcmp(spm_file(niftiFile{1},'ext'),'gz'), niftiFile = spm_file(niftiFile,'ext',''); end
        for fileInd = 1:numel(V)
            Y = spm_read_vols(V(fileInd));
            if numel(niftiFile) == 1 % 4D-NIFTI
                fn = spm_file(niftiFile(1),'path',runpth,'suffix',sprintf('_%04d',fileInd));
            else % 3D-NIFTI
                fn = spm_file(niftiFile(fileInd),'path',runpth);
            end
            V(fileInd).fname = fn{1};
            V(fileInd).n = [1 1];
            spm_write_vol(V(fileInd),Y);
            finalepis = [finalepis fn];
        end

        if isfield(header{1},'PhaseEncodingDirection') && ~isempty(header{1}.PhaseEncodingDirection(1))
            sliceaxes = {'x' 'y'};
            ind = cellfun(@(t) contains(header{1}.PhaseEncodingDirection(1),t), sliceaxes);
            if ind == 0 % newer BIDS spec uses this format instead
                sliceaxes = {'i' 'j'};
                ind = cellfun(@(t) contains(header{1}.PhaseEncodingDirection(1),t), sliceaxes);
            end
            if ind == 0
                logging.error('Could not parse PhaseEncodingDirection: %s', header{1}.PhaseEncodingDirection(1));
            end
            logging.info('PhaseEncodingDirection is %s',sliceaxes(ind));
            header{1}.NumberOfPhaseEncodingSteps = V(1).dim(ind);
        end

        %% Write out the files

        % Now move dummy scans to dummyscans directory
        dummylist=[];
        if numdummies
            dummypath = fullfile(runpth,'dummyscans');
            dirMake(dummypath);
            for d = 1:numdummies
                movefile(finalepis{d},dummypath);
            end
            dummylist = finalepis(1:d);
        else
            d = 0;
        end
        finalepis(1:d) = [];
        V(1:d) = [];

        % 4D conversion
        finalepis = finalepis{1};
        ind = regexp(finalepis,'_[0-9]*\.'); % find volume numbers just before the extension
        sfx = '';
        if isempty(ind)
            ind = find(finalepis=='.',1,'last');
            sfx = '_4D';
        end
        finalepis = [finalepis(1:ind-1) sfx '.nii'];
        if iscell(V), V = cell2mat(V); end
        V = spm_file_merge(char({V.fname}),finalepis,0,header{1}.volumeTR);

        % And describe outputs
        putFileByStream(rap,'fmrirun',[subj run],'fmri',finalepis);
        if ~isempty(dummylist), putFileByStream(rap,'fmrirun',[subj run],'dummyscans',dummylist); end

        hdrfn = fullfile(runpth,'fmri_headers.mat');
        save(hdrfn,'header');
        putFileByStream(rap,'fmrirun',[subj run],'fmri_header',hdrfn);

        % QA
        Y = spm_read_vols(V);
        Ymean = mean(Y,4);
        QA.sd = std(Y,[],4); QA.sd(QA.sd==0) = NaN;
        QA.snr = Ymean./QA.sd;
        if ~isempty(header{1}.EchoTime), QA.cnr = Ysnr*header{1}.EchoTime; end
        for m = fieldnames(QA)'
            V(1).fname = spm_file(finalepis,'suffix',['_' m{1}]);
            spm_write_vol(V(1),QA.(m{1}));
            putFileByStream(rap,'fmrirun',[subj run],['fmri_' m{1}],V(1).fname);
        end
    case 'checkrequirements'

end
end

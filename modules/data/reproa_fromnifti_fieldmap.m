function rap = reproa_fromnifti_fieldmap(rap,command,subj,run)

    switch command
        case 'doit'
            localPath = fullfile(getPathByDomain(rap,rap.tasklist.currenttask.domain,[subj, run]),rap.directoryconventions.fieldmapsdirname);
            dirMake(localPath);

            % Find specification
            if ~iscell(rap.acqdetails.subjects(subj).fieldmaps{1}) || ~isstruct(rap.acqdetails.subjects(subj).fieldmaps{1}{1}), logging.error('Was exepcting list of structs in cell array'); end;
            niftistruct = [];
            % try session-specific --> visit-specific --> rest
            visitNum = getSeriesNumber(rap,subj,run);
            fieldmaps = [rap.acqdetails.subjects(subj).fieldmaps(visitNum:end) rap.acqdetails.subjects(subj).fieldmaps(1:visitNum-1)];
            for n = horzcat(fieldmaps{:})
                if ~isempty(regexp([getRunType(rap) '-' rap.acqdetails.([getRunType(rap) 's'])(run).name],strrep(n{1}.run,'*','.*')))
                    if ~isempty(getSetting(rap,'pattern')) && isempty(regexp(n{1}.fname{1},getSetting(rap,'pattern'))), continue; end
                    niftistruct = n{1};
                    break;
                end
            end
            if isempty(niftistruct), logging.error('No fieldmap found for %s run "%s"',getRunType(rap),getRunName(rap,run)); end

            % Locate files
            niftiFile = niftistruct.fname;
            hdrFile = niftistruct.hdr;
            if ~exist(niftiFile{1},'file')
                niftiFile = '';
                for niftisearchpth = cellfun(@(d) findData(rap,'mri',d), rap.acqdetails.subjects(subj).mridata,'UniformOutput',false);
                    niftiFile = fullfile(niftisearchpth{1},niftiFile);
                    if exist(niftiFile,'file'), break; end
                end
                if isempty(niftiFile), logging.error(['Image ' niftiFile ' not found']); end
                if ischar(hdrFile), hdrFile = spm_file(hdrFile,'path',niftisearchpth{1}); end
            end

            % Header
            if ischar(hdrFile) && strcmp(spm_file(hdrFile,'ext'),'mat') % already processed by reproa
                load(hdrFile,'dcmhdr');
            else
                if isstruct(hdrFile)
                    dcmhdr{1} = hdrFile;
                elseif ischar(hdrFile) && strcmp(spm_file(hdrFile,'ext'),'json') % BIDS
                    dcmhdr{1} = jsonread(hdrFile);
                end
                % convert timings to ms (consistent with DICOM)
                for f = fieldnames(dcmhdr{1})'
                    if strfind(f{1},'Time'), dcmhdr{1}.(f{1}) = dcmhdr{1}.(f{1})*1000; end
                end
                if isfield(dcmhdr{1},'RepetitionTime'), dcmhdr{1}.volumeTR = dcmhdr{1}.RepetitionTime/1000; end
                if isfield(dcmhdr{1},'EchoTime'), dcmhdr{1}.volumeTE = dcmhdr{1}.EchoTime/1000; end
            end

            if isfield(dcmhdr{1},'volumeTE') && numel(dcmhdr{1}.volumeTE) == 2 % dual-echo
                logging.info('Dual-echo fieldmap detected');
                localPath = fullfile(localPath,'dualecho');
                streamPrefix = 'dualte';
                % heuristics based on filename following BIDS
                switch numel(niftiFile)
                    case 8 % (shortmag, shortphase, shortreal, shortimag, longmag, longphase, longreal, longimag) (GE)
                        logging.error('NYI: GE fieldmap with %d files',numel(niftiFile))
                    case 4 % (shortreal, shortimag, longreal, longimag) (Philips)
                        logging.error('NYI: Philips fieldmap with %d files',numel(niftiFile))
                    case 3 % (shortmag, longmag, phasediff) (Siemens)
                        output.phasediff = niftiFile(lookFor(niftiFile,'phasediff'));
                        [~,ord] = sort(dcmhdr{1}.volumeTE);
                        output.shortmag = niftiFile(lookFor(niftiFile,sprintf('magnitude%d',ord(1))));
                        output.longmag = niftiFile(lookFor(niftiFile,sprintf('magnitude%d',ord(2))));
                    otherwise
                        logging.error('NYI: %d fieldmap files',numel(niftiFile))
                end
            elseif isfield(dcmhdr{1},'PhaseEncodingDirection') && numel(dcmhdr{1}.PhaseEncodingDirection) == 2 % dual phase-encoding
                logging.info('Dual-phaseencoding fieldmap detected');
                localPath = fullfile(localPath,'dualphaseencoding');
                streamPrefix = 'dualpe';
                output.files = niftiFile;
            else, logging.error('Fieldmap type cannot be detected!');
            end
            dirMake(localPath);
            fn = fullfile(localPath,'fieldmap_header.mat');
            if isOctave
                save('-mat-binary',fn,'dcmhdr');
            else
                save(fn,'dcmhdr');
            end
            putFileByStream(rap,rap.tasklist.currenttask.domain,[subj run],[streamPrefix 'fieldmap_header'],fn);

            % Images
            for t = fieldnames(output)'
                for f = 1:numel(output.(t{1}))
                    if strcmp(spm_file(output.(t{1}){f},'ext'),'gz')
                        gunzip(output.(t{1}){f},localPath);
                        output.(t{1}){f} = spm_file(output.(t{1}){f},'path',localPath,'ext','');
                    else
                        movefile(output.(t{1}){f},localPath);
                        output.(t{1}){f} = spm_file(output.(t{1}){f},'path',localPath);
                    end
                end
            end

            putFileByStream(rap,rap.tasklist.currenttask.domain,[subj run],[streamPrefix 'fieldmap'],output);
    end
end

function rap = fromnifti_fieldmap(rap,command,subj,run)

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
                if any(strcmp(n{1}.run,...
                       {[getRunType(rap) '-' rap.acqdetails.([getRunType(rap) 's'])(run).name] ...
                       [getRunType(rap) '-*']
                       }))
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
            if isstruct(hdrFile)
                dcmhdr{1} = hdrFile;
            else
                switch spm_file(hdrFile,'Ext')
                    case 'mat'
                        load(hdrFile,'dcmhdr');
                    case 'json'
                        hdrFile = loadjson(hdrFile);
                        % convert timings to ms (DICOM default)
                        for f = fieldnames(hdrFile)'
                            if strfind(f{1},'Time'), dcmhdr{1}.(f{1}) = hdrFile.(f{1})*1000; end
                        end
                        if isfield(dcmhdr{1},'RepetitionTime'), dcmhdr{1}.volumeTR = dcmhdr{1}.RepetitionTime/1000; end
                        if isfield(dcmhdr{1},'EchoTime1') && isfield(dcmhdr{1},'EchoTime2'), dcmhdr{1}.volumeTE = [dcmhdr{1}.EchoTime1 dcmhdr{1}.EchoTime2]/1000;
                        elseif isfield(dcmhdr{1},'EchoTime'), dcmhdr{1}.volumeTE = dcmhdr{1}.EchoTime/1000;
                        end
                end
            end
            if isfield(dcmhdr{1},'volumeTE') && numel(dcmhdr{1}.volumeTE) == 2 % dual-echo
                logging.info('Dual-echo fieldmap detected');
                localPath = fullfile(localPath,'dualecho');
                streamPrefix = 'dualte';
            elseif isfield(dcmhdr{1},'PhaseEncodingDirection') && numel(dcmhdr{1}.PhaseEncodingDirection) == 2 % dual phase-encoding
                logging.info('Dual-phaseencoding fieldmap detected');
                localPath = fullfile(localPath,'dualphaseencoding');
                streamPrefix = 'dualpe';
            else, logging.error('Fieldmap type cannot be detected!');
            end
            dirMake(localPath);
            fn = fullfile(localPath,'fieldmap_header.mat');
            save(fn,'dcmhdr');
            putFileByStream(rap,rap.tasklist.currenttask.domain,[subj run],[streamPrefix 'fieldmap_header'],fn);

            % Images
            for f = 1:numel(niftiFile)
                if strcmp(spm_file(niftiFile{f},'ext'),'gz')
                    gunzip(niftiFile{f},localPath);
                    niftiFile{f} = spm_file(niftiFile{f},'path',localPath,'ext','');
                else
                    movefile(niftiFile{f},localPath);
                    niftiFile{f} = spm_file(niftiFile{f},'path',localPath);
                end
            end
            putFileByStream(rap,rap.tasklist.currenttask.domain,[subj run],[streamPrefix 'fieldmap'],niftiFile);
    end
end

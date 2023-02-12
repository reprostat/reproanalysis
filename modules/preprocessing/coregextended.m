% extended coregistration of fMRI to structural
% Coregistration of structural to mean fMRI output by realignment in 3 steps
% 1) Coregister Structural to T1 template
% 2) Coregister mean fMRI to fMRI template
% 3) Coregister mean fMRI to Structural
% 4) Apply transformation matrix of mean fMRI to all fMRIs

function rap = coregextended(rap,command,subj)

    switch command
        case 'report' % [TA]
            reportStore = sprintf('sub%d',subj);
            imgToReport = {...
                'Mean fMRI to structural' spm_file(getFileByStream(rap,'subject',subj,'structural','checkHash',false),'basename'); ...
                'Structural to mean fMRI' spm_file(getFileByStream(rap,'subject',subj,'meanfmri','checkHash',false),'basename') ...
                };

            fdiag = spm_select('FPList', getPathByDomain(rap,'subject',subj),['^diagnostic_.*.mp4$']);
            if ~isempty(fdiag)
                imgToReport = [imgToReport; ...
                    'Video' {spm_file(getFileByStream(rap,'subject',subj,'fmri','checkHash',false),'basename')} ...
                ];
            end

            for r = 1:size(imgToReport,1)
                if contains(imgToReport{r,1},'Video'), ext = 'mp4'; else, ext = 'jpg'; end
                fdiag = spm_select('FPList', getPathByDomain(rap,'subject',subj),['^diagnostic_.*' imgToReport{r,2}{1} '.' ext '$']);
                addReport(rap,reportStore,'<table><tr><td>');
                addReport(rap,reportStore,['<h4>' imgToReport{r,1} '</h4>']);
                rap = addReportMedia(rap,reportStore,fdiag);
                addReport(rap,reportStore,'</td></tr></table>');
            end
        case 'doit'
            global reproacache
            SPM = reproacache('toolbox.spm');
            SPM.reload(true); % update defaults

            % Check the template
            % - T1 template
            sTimg = rap.directoryconventions.SPMT1;
            if ~exist(sTimg,'file'), sTimg = fullfile(spm('dir'), sTimg); end
            if ~exist(sTimg,'file'), logging.error('Couldn''t find template T1 image %s.', sTimg); end
            sTimg = which(sTimg);

            % - fMRI template
            eTimg = fullfile(fileparts(sTimg), 'EPI.nii');
            if ~exist(eTimg, 'file'), logging.error('Couldn''t find template fMRI image %s.', eTimg); end
            eTimg = which(eTimg);

            % Coregister
            Simg = getFileByStream(rap,'subject',subj,'structural');
            if numel(Simg) > 1, logging.error('Found more than 1 structural images. Make sure you set rap.options.autoidentifystructural correctly.'); end
            Simg = Simg{1};
            mfMRIimg = getFileByStream(rap,'subject',subj,'meanfmri'); mfMRIimg = mfMRIimg{1};

            runCoreg(Simg,sTimg,'Structural to template');
            runCoreg(mfMRIimg,eTimg,'Mean fMRI to template');
            runCoreg(mfMRIimg,Simg,'Mean fMRI to structural');

            % Apply transformation to fMRI

            % - get space of mean functional
            MM = spm_get_space(mfMRIimg);

            fMRIimg = cell(1,numel(rap.acqdetails.fmriruns));
            % Locate all the fMRIs we want to coregister
            for run = rap.acqdetails.selectedruns
                fMRIimg{run} = getFileByStream(rap,'fmrirun',[subj,run],'fmri');

                % For each image, apply the space of the mean fMRI image
                for e = 1:numel(fMRIimg{run})
                    % Apply the space of the coregistered mean fMRI to the
                    % remaining fMRIs (safest solution!)
                    spm_get_space(fMRIimg{run}{e}, MM);
                end
            end

            % Describe the outputs
            putFileByStream(rap,'subject',subj,'structural',Simg);
            putFileByStream(rap,'subject',subj,'meanfmri',mfMRIimg);
            for run = rap.acqdetails.selectedruns
                putFileByStream(rap,'fmrirun',[subj run],'fmri',fMRIimg{run});
            end

            % Diagnostics
            registrationCheck(rap,'subject',subj,'structural','meanfmri',spm_file(fMRIimg{rap.acqdetails.selectedruns(1)}{1},'number',',1'))
    end
end

function runCoreg(inputImg,targetImg,desc)
    global defaults
    flags = defaults.coreg.estimate;

    % Coregister
    x = spm_coreg(targetImg, inputImg, flags);
    M = inv(spm_matrix(x));

    % Set the new space for the structural
    spm_get_space(inputImg, M*spm_get_space(inputImg));

    % Report
    logging.info('%s realignment parameters:\n\tx: %1.3f | y: %1.3f | z: %1.3f | p: %1.3f | r: %1.3f | j: %1.3f', desc, x(1:6))
end

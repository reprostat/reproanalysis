% extended coregistration of fMRI to structural
% Coregistration of structural to mean fMRI output by realignment in 3 steps
% 1) Coregister Structural to T1 template
% 2) Coregister mean fMRI to fMRI template
% 3) Coregister mean fMRI to Structural
% 4) Apply transformation matrix of mean fMRI to all fMRIs

function rap = reproa_coregextended(rap,command,subj)

    switch command
        case 'report' % [TA]
            rap = registrationReport(rap,subj);

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
            if ~getSetting(rap,'reorienttotemplate') && strcmp(getSetting(rap,'target'),'structural') % preserve original image
                copyfile(Simg,spm_file(Simg,'basename','tmpStruct'));
                Simg = spm_file(Simg,'basename','tmpStruct');
            end
            if hasStream(rap,'subject',subj,'meanfmri')
                mfMRIimg = getFileByStream(rap,'subject',subj,'meanfmri'); mfMRIimg = mfMRIimg{1};
                if ~getSetting(rap,'reorienttotemplate') && strcmp(getSetting(rap,'target'),'meanfmri') % preserve original image
                    copyfile(mfMRIimg,spm_file(mfMRIimg,'basename','tmpMeanfmri'));
                    mfMRIimg = spm_file(mfMRIimg,'basename','tmpMeanfmri');
                end
            else % create from fmri (1st run only, assumes coregsitered/realigned runs)
                fMRIimg = char(getFileByStream(rap,'fmrirun',[subj rap.acqdetails.selectedruns(1)],'fmri'));
                mfMRIimg = spm_file(fMRIimg,'prefix','mean_');
                V = spm_vol(fMRIimg);
                Y = spm_read_vols(V);
                V = V(1); Y = mean(Y,4); V.fname = mfMRIimg;
                spm_write_vol(V,Y);
            end

            preMstruct = runCoreg(Simg,sTimg,'Structural to template');
            preMfmri = runCoreg(mfMRIimg,eTimg,'Mean fMRI to template');
            doCoregFmri = false;
            switch getSetting(rap,'target')
                case 'meanfmri'
                    runCoreg(Simg,mfMRIimg,'Mean structural to fMRI');
                    if getSetting(rap,'reorienttotemplate')
                        putFileByStream(rap,'subject',subj,'meanfmri',mfMRIimg);
                        doCoregFmri = true;
                    else
                        spm_get_space(Simg, inv(preMfmri)*spm_get_space(Simg));
                        delete(mfMRIimg);
                    end

                    putFileByStream(rap,'subject',subj,'structural',Simg);
                case 'structural'
                    doCoregFmri = true;
                    runCoreg(mfMRIimg,Simg,'Mean fMRI to structural');
                    if getSetting(rap,'reorienttotemplate')
                        putFileByStream(rap,'subject',subj,'structural',Simg);
                    else
                        delete(Simg);
                        spm_get_space(mfMRIimg, inv(preMstruct)*spm_get_space(mfMRIimg));
                    end

                    putFileByStream(rap,'subject',subj,'meanfmri',mfMRIimg);
            end

            if doCoregFmri
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
                        % remaining fMRIs (safest solution!, assumes coregsitered/realigned runs)
                        spm_get_space(fMRIimg{run}{e}, MM);
                    end
                end

                % Describe the outputs
                for run = rap.acqdetails.selectedruns
                    putFileByStream(rap,'fmrirun',[subj run],'fmri',fMRIimg{run});
                end

                % Diagnostics
                registrationCheck(rap,'subject',subj,'structural','meanfmri',spm_file(fMRIimg{rap.acqdetails.selectedruns(1)}{1},'number',',1'));
            else

                % Diagnostics
                if hasStream(rap,'subject',subj,'meanfmri'), registrationCheck(rap,'subject',subj,'structural','meanfmri');
                else
                    if iscell(fMRIimg), fMRIimg = fMRIimg{rap.acqdetails.selectedruns(1)}{1}; end
                    registrationCheck(rap,'subject',subj,'structural',spm_file(fMRIimg,'number',',1'));
                end
            end

        case 'checkrequirements'
            if ~getSetting(rap,'reorienttotemplate')
                targetStream = getSetting(rap,'target');
                if ismember(targetStream,{rap.tasklist.currenttask.outputstreams.name})
                    rap = renameStream(rap,rap.tasklist.currenttask.name,'output',targetStream,[]);
                    logging.info('REMOVED: %s output stream: %s', rap.tasklist.currenttask.name,targetStream);
                end
                if strcmp(targetStream,'meanfmri') && ismember('fmri',{rap.tasklist.currenttask.outputstreams.name})
                    rap = renameStream(rap,rap.tasklist.currenttask.name,'output','fmri',[]);
                    logging.info('REMOVED: %s output stream: %s', rap.tasklist.currenttask.name,'fmri');
                end
            end
    end
end

function M = runCoreg(inputImg,targetImg,desc)
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

% Extended coregistration with structural by realignment to MNI (always applied, optionally saved)
% 1) Coregister structural to T1 template
% 2) Coregister input to corresponding template (fMRI -> EPI, T2 -> T2)
% 3) Coregister input with structural (any direction)
% 4) Apply transformation matrix to other inputs

function rap = reproa_coregextended(rap,command,subj)

  % Configure
    if hasStream(rap,'fmri'), coregStream = 'meanfmri'; otherStream = 'fmri'; bTimg = 'EPI';
    elseif hasStream(rap,'t2'), coregStream = 't2'; otherStream = ''; bTimg = 'T2';
    end

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

            % - input template
            eTimg = fullfile(fileparts(sTimg), [bTimg '.nii']);
            if ~exist(eTimg, 'file'), logging.error('Couldn''t find template %s image %s.', bTimg,eTimg); end
            eTimg = which(eTimg);

            % Coregister
            Simg = getFileByStream(rap,'subject',subj,'structural');
            if numel(Simg) > 1, logging.error('Found more than 1 structural images. Make sure you set rap.options.autoidentifystructural correctly.'); end
            Simg = Simg{1};
            if ~getSetting(rap,'reorienttotemplate') && strcmp(getSetting(rap,'target'),'structural') % preserve original image
                copyfile(Simg,spm_file(Simg,'basename','tmpStruct'));
                Simg = spm_file(Simg,'basename','tmpStruct');
            end
            if hasStream(rap,'subject',subj,coregStream)
                mfMRIimg = getFileByStream(rap,'subject',subj,coregStream); mfMRIimg = mfMRIimg{1}; % use only the first
                if ~getSetting(rap,'reorienttotemplate') && strcmp(getSetting(rap,'target'),coregStream) % preserve original image
                    copyfile(mfMRIimg,spm_file(mfMRIimg,'basename','tmpCoreg'));
                    mfMRIimg = spm_file(mfMRIimg,'basename','tmpCoreg');
                end
            else % create from otherStream (1st run only, assumes coregsitered/realigned runs)
                fMRIimg = char(getFileByStream(rap,[otherStream 'run'],[subj rap.acqdetails.selectedruns(1)],otherStream));
                mfMRIimg = spm_file(fMRIimg,'prefix','mean_');
                V = spm_vol(fMRIimg);
                Y = spm_read_vols(V);
                V = V(1); Y = mean(Y,4); V.fname = mfMRIimg;
                spm_write_vol(V,Y);
            end

            preMstruct = runCoreg(Simg,sTimg,'Structural to template');
            preMfmri = runCoreg(mfMRIimg,eTimg,'Input to template');
            doCoregOther = false;
            if strcmp(getSetting(rap,'target'),'structural')
                doCoregOther = true;
                runCoreg(mfMRIimg,Simg,'Input to structural');
                if getSetting(rap,'reorienttotemplate')
                    putFileByStream(rap,'subject',subj,'structural',Simg);
                else
                    delete(Simg);
                    spm_get_space(mfMRIimg, inv(preMstruct)*spm_get_space(mfMRIimg));
                end

                putFileByStream(rap,'subject',subj,coregStream,mfMRIimg);
            else
                runCoreg(Simg,mfMRIimg,'Structural to Input');
                if getSetting(rap,'reorienttotemplate')
                    putFileByStream(rap,'subject',subj,coregStream,mfMRIimg);
                    doCoregOther = true;
                else
                    spm_get_space(Simg, inv(preMfmri)*spm_get_space(Simg));
                    delete(mfMRIimg);
                end

                putFileByStream(rap,'subject',subj,'structural',Simg);
            end

            if ~isempty(otherStream) && doCoregOther
                % Apply transformation to fMRI

                % - get space of mean functional
                MM = spm_get_space(mfMRIimg);

                fMRIimg = cell(1,numel(rap.acqdetails.fmriruns));
                % Locate all the fMRIs we want to coregister
                for run = rap.acqdetails.selectedruns
                    fMRIimg{run} = getFileByStream(rap,[otherStream 'run'],[subj,run],otherStream);

                    % For each image, apply the space of the mean fMRI image
                    for e = 1:numel(fMRIimg{run})
                        % Apply the space of the coregistered mean fMRI to the
                        % remaining fMRIs (safest solution!, assumes coregsitered/realigned runs)
                        spm_get_space(fMRIimg{run}{e}, MM);
                    end
                end

                % Describe the outputs
                for run = rap.acqdetails.selectedruns
                    putFileByStream(rap,[otherStream 'run'],[subj run],otherStream,fMRIimg{run});
                end

                % Diagnostics
                registrationCheck(rap,'subject',subj,'structural',coregStream,spm_file(fMRIimg{rap.acqdetails.selectedruns(1)}{1},'number',',1'));
            else

                % Diagnostics
                if hasStream(rap,'subject',subj,coregStream), registrationCheck(rap,'subject',subj,'structural',coregStream);
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

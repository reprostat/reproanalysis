% Extended coregistration with structural by realignment to MNI (always applied, optionally saved)
% 1) Coregister structural to T1 template
% 2) Coregister input to corresponding template (fMRI -> EPI, T2 -> T2)
% 3) Coregister input with structural (any direction)
% 4) Apply transformation matrix to other inputs

function rap = reproa_coregextended(rap,command,varargin)

  % Configure
    subj = varargin{1};
    localPath = getPathByDomain(rap,rap.tasklist.currenttask.domain,cell2mat(varargin));
    if hasStream(rap,'meanfmri'), coregStream = 'meanfmri'; bTimg = 'EPI'; otherDomain = 'fmrirun';
    elseif hasStream(rap,'t2'), coregStream = 't2'; bTimg = 'T2'; otherDomain = 'subject'
    end
    otherStream = setdiff({rap.tasklist.currenttask.inputstreams.name},{'structural' coregStream},'stable'); % first other is used for diagnostics

    switch command
        case 'report' % [TA]
            rap = registrationReport(rap,varargin{:});

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
            % - structural
            Simg = getFileByStream(rap,'subject',subj,'structural');
            if numel(Simg) > 1, logging.error('Found more than 1 structural images. Make sure you set rap.options.autoidentifystructural correctly.'); end
            Simg = Simg{1};
            if ~getSetting(rap,'reorienttotemplate') && strcmp(getSetting(rap,'target'),'structural') % preserve original image
                copyfile(Simg,spm_file(Simg,'path',localPath,'basename','tmpStruct'));
                Simg = spm_file(Simg,'path',localPath,'basename','tmpStruct');
            end

            % - coreg data
            mfMRIimg = getFileByStream(rap,rap.tasklist.currenttask.domain,cell2mat(varargin),coregStream); mfMRIimg = mfMRIimg{1}; % use only the first
            if ~getSetting(rap,'reorienttotemplate') && strcmp(getSetting(rap,'target'),coregStream) % preserve original image
                copyfile(mfMRIimg,spm_file(mfMRIimg,'path',localPath,'basename','tmpCoreg'));
                mfMRIimg = spm_file(mfMRIimg,'path',localPath,'basename','tmpCoreg');
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

                putFileByStream(rap,rap.tasklist.currenttask.domain,cell2mat(varargin),coregStream,mfMRIimg);
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
                % Apply transformation to others

                % - get space of mean functional
                MM = spm_get_space(mfMRIimg);

                % Locate all the fMRIs we want to coregister
                if numel(varargin) == 1, runs = rap.acqdetails.selectedruns;
                else, runs = varargin{2};
                end
                for run = runs
                    for s = otherStream
                        img = getFileByStream(rap,otherDomain,[subj,run],s{1});

                        % For each image, apply the space of the mean fMRI image
                        for e = 1:numel(img)
                            % Apply the space of the coregistered mean fMRI to the
                            % remaining fMRIs (safest solution!, assumes coregsitered/realigned runs)
                            spm_get_space(img{e}, MM);
                        end

                        % Describe the outputs
                        putFileByStream(rap,otherDomain,[subj run],s{1},img);
                    end
                end

                % Diagnostics
                registrationCheck(rap,rap.tasklist.currenttask.domain,cell2mat(varargin),'structural',coregStream,[otherStream{1} ',1']);
            else

                % Diagnostics
                registrationCheck(rap,rap.tasklist.currenttask.domain,cell2mat(varargin),'structural',coregStream);
            end

        case 'checkrequirements'
            % Ensure that all (new) others are outputs
            for s = otherStream
                if ~ismember(s{1},{rap.tasklist.currenttask.outputstreams.name})
                    rap = renameStream(rap,rap.tasklist.currenttask.name,'output','append',...
                                       [s{1} ':domain-' rap.tasklist.currenttask.inputstreams(strcmp({rap.tasklist.currenttask.inputstreams.name},s{1})).streamdomain]);
                    logging.info('NEW: %s output stream: %s', rap.tasklist.currenttask.name,s{1});
                end
            end

            % Remove target from outputs and others in the space space from inputs and outputs, if not to be reoriented.
            if ~getSetting(rap,'reorienttotemplate')
                targetStream = getSetting(rap,'target');
                if ismember(targetStream,{rap.tasklist.currenttask.outputstreams.name})
                    rap = renameStream(rap,rap.tasklist.currenttask.name,'output',targetStream,[]);
                    logging.info('REMOVED: %s output stream: %s', rap.tasklist.currenttask.name,targetStream);
                end
                if ~strcmp(targetStream,'structural')
                    for s = otherStream
                        if ismember(s{1},{rap.tasklist.currenttask.inputstreams.name})
                            rap = renameStream(rap,rap.tasklist.currenttask.name,'input',s{1},[]);
                            logging.info('REMOVED: %s input stream: %s', rap.tasklist.currenttask.name,s{1});
                        end
                        if ismember(s{1},{rap.tasklist.currenttask.outputstreams.name})
                            rap = renameStream(rap,rap.tasklist.currenttask.name,'output',s{1},[]);
                            logging.info('REMOVED: %s output stream: %s', rap.tasklist.currenttask.name,s{1});
                        end
                    end
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

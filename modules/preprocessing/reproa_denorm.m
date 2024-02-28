function rap = reproa_denorm(rap,command,varargin)

    switch command
        case 'report'
            rap = registrationReport(rap,varargin{:});

        case 'doit'
            global reproacache
            SPM = reproacache('toolbox.spm');
            SPM.reload(true); % update defaults
            global defaults;

            indices = cell2mat(varargin);
            domain = rap.tasklist.currenttask.domain;
            localPath = getPathByDomain(rap,domain,indices);
            regStream = {rap.tasklist.currenttask.inputstreams(~[rap.tasklist.currenttask.inputstreams.isessential]).name};
            for s = 1:numel(regStream)
                if iscell(regStream{s}), regStream(s) = regStream{s}(end); end % renamed -> used original
            end

            %% Prepare
            flagsW.prefix = defaults.normalise.write.prefix;
            if hasStream(rap,'inverse_deformationfield')
                trans = getFileByStream(rap,'subject',indices(1),'inverse_deformationfield');
                [flagsW.bb, flagsW.vox] = spm_get_bbox(cell2mat(spm_vol(getFileByStream(rap,domain,indices,regStream{1}))));
                flagsW.interp = getSetting(rap,'interp');
            elseif hasStream(rap,'dartelflowfield')
                job.flowfields = getFileByStream(rap, 'subject',indices(1), 'dartelflowfield');
                job.interp = getSetting(rap,'interp');
                job.K = 6;
            else
                logging.error('No transformation specified!')
            end

            %% Denormalise
            streams = {rap.tasklist.currenttask.outputstreams.name};
            for streamInd = 1:numel(streams)
                if iscell(streams{streamInd}), streams{streamInd} = streams{streamInd}{end}; end % renamed -> used original
                imgs = getFileByStream(rap,rap.tasklist.currenttask.domain,indices,streams{streamInd}); imgs0 = imgs;
                if isstruct(imgs), imgs = struct2cell(imgs); imgs = cat(1,imgs{:}); end

                % Prechecks
                for c = 1:numel(imgs)
                    % - delete previous because otherwise nifti write routine doesn't save disc space when you reslice to a coarser voxel
                    thisfile = spm_file(imgs{c},'prefix',flagsW.prefix);
                    if exist(thisfile,'file'), delete(thisfile); end

                    % - make a working copy in the working folder to avoid interference
                    if ~strcmp(spm_file(imgs{c},'path'),localPath)
                        imgsLocal = spm_file(imgs{c},'path',localPath);
                        copyfile(imgs{c}, imgsLocal);
                        imgs{c} = imgsLocal;
                    end
                end

                % Apply transformation
                if hasStream(rap,'inverse_deformationfield')
                    switch spm('ver')
                        case 'SPM8'
                            job.ofname = '';
                            job.fnames = imgs;
                            job.savedir.saveusr{1} = getPathByDomain(rap,rap.tasklist.currenttask.domain,indices);
                            job.interp = flagsW.interp;
                            job.comp{1}.def = trans;
                            spm_defs(job);
                        case {'SPM12b' 'SPM12'}
                            job.subj.def = trans;
                            job.subj.resample = imgs;
                            job.woptions = flagsW;
                            spm_run_norm(job);
                        otherwise
                            logging.error('%s requires SPM8 or later.', mfilename);
                    end
                elseif hasStream(rap,'dartelflowfield')
                    job.images = imgs;
                    spm_dartel_invnorm(job);
                end
                wimgs = spm_file(imgs,'prefix',flagsW.prefix);

                % De-coreg if needed
                fnReg = cellfun(@(s) getFileByStream(rap,domain,indices,s),regStream);
                if numel(fnReg)>2 || ~all(cellfun(@ischar, fnReg))
                    logging.error('%s:',mfile);
                end
                matReg = cellfun(@(fn) spm_get_space(fn),fnReg, 'UniformOutput',false);
                if numel(regStream) == 2 && ~strcmp(fnReg{:}) && ~isequal(matReg{:})
                    xfm = matReg{2}/matReg{1};
                    cellfun(@(fn) spm_get_space(fn,xfm*spm_get_space(fn)), wimgs);
                end

                % Reslice
                flagsR = defaults.coreg.write;
                flagsR.interp = getSetting(rap,'interp');
                flagsR.which = [1 0];
                spm_reslice([fnReg(end) wimgs],flagsR);
                wimgs = spm_file(wimgs,'prefix',flagsR.prefix)

                % Binarise if specified
                if ~isempty(getSetting(rap,'binarise'))
                    thr = getSetting(rap,'binarise',streamInd);
                    if thr
                        for e = 1:numel(wimgs)
                            V = spm_vol(wimgs{e});
                            Y = spm_read_vols(V);
                            % for iv = 1:numel(V), V(iv).pinfo = [1; 0; 0]; end
                            V = V(1);
                            Y = Y >= thr;
                            V.descrip = 'Binarized';
                            niftiWrite(V,Y,'Binarized')
                        end
                    end
                end

                % Describe outputs
                if isstruct(imgs0)
                    wimgs = struct;
                    for f = fieldnames(imgs0)'
                        wimgs.(f{1}) = spm_file(imgs0.(f{1}),'path',localPath,'prefix',[flagsR.prefix flagsW.prefix]);
                    end
                end
                putFileByStream(rap,rap.tasklist.currenttask.domain,indices,streams{streamInd},wimgs);

            end

            %% Diagnostic
            cfgDiag = getSetting(rap,'diagnostic');
            if isempty(cfgDiag) ||... % do it by default
                (~isstruct(cfgDiag) && cfgDiag) ||... % general
                (isstruct(cfgDiag) && cfgDiag.streamInd)
                streamToReport = {rap.tasklist.currenttask.outputstreams.name};
                for s = 1:numel(streamToReport)
                    if iscell(streamToReport{s}), streamToReport{s} = streamToReport{s}{end}; end % renamed -> used original
                    if lookFor(streamToReport{s},'segmentations'), content{s} = {'GM'};
                    else, content{s} = {};
                    end
                end
                if isstruct(cfgDiag) && cfgDiag.streamInd
                    streamToReport = streamToReport(cfgDiag.streamInd);
                end
                for s = 1:numel(streamToReport)
                    img = getFileByStream(rap,rap.tasklist.currenttask.domain,indices,streamToReport{s},'streamType','output','content',content{s});
                    if isstruct(img), img = img.(content{s}{1}); end
                    fnImg{s} = spm_file(img{1},'number',',1');
                end
                registrationCheck(rap,rap.tasklist.currenttask.domain,indices,fnReg{end},fnImg{:});
            end

        case 'checkrequirements'
            % Ensure that at least one non-essential regstreams is present
            if ~any(~[rap.tasklist.currenttask.inputstreams.isessential])
                logging.error('%s:at least one non-essential registration target streams MUST be present',mfilename);
            end


            % Ensure that output matches with input
            rap = passStreams(rap,{'inverse_deformationfield'...
                                   'darteltemplate' 'darteltemplatetomni' 'dartelflowfield'...
                                   'meanfmri', 'meanfmri_native'});
    end
end

function rap = reproa_normwrite(rap,command,varargin)

    switch command
        case 'report'
            rap = registrationReport(rap,varargin{:},'addToSummary');

        case 'doit'
            global reproacache
            SPM = reproacache('toolbox.spm');
            SPM.reload(true); % update defaults
            global defaults;

            indices = cell2mat(varargin);
            localPath = getPathByDomain(rap,rap.tasklist.currenttask.domain,indices);

            % prepare
            flags = defaults.normalise.write;
            if hasStream(rap,'forward_deformationfield')
                trans = getFileByStream(rap,'subject',indices(1),'forward_deformationfield');
            elseif hasStream(rap,'darteltemplate')
                % - template
                template = char(getFileByStream(rap, 'study',[], 'darteltemplate'));
                if ~exist(spm_file(template,'path',localPath),'file')
                    copyfile(template,localPath);
                end
                template = spm_file(template,'path',localPath);

                % - to MNI XFM
                load(char(getFileByStream(rap,rap.tasklist.currenttask.domain,indices,'darteltemplatetomni')),'xfm');
                MMt = spm_get_space(template);
                mni.code = 'MNI152';
                mni.affine = xfm*MMt;
                save(spm_file(template,'suffix','_2mni','ext','mat'),'mni');

                % - configure
                job.data.subj.flowfield = getFileByStream(rap, 'subject',indices(1), 'dartelflowfield');
                job.template{1} = template;
                job.bb = reshape(getSetting(rap,'write.bb'),2,3);
                job.vox = getSetting(rap,'write.vox');
                job.fwhm = getSetting(rap,'fwhm');
                % -- preserve
                [val, ~, attr] = getSetting(rap,'preserve');
                job.preserve = find(strcmp(strsplit(attr.options,'|'),val))-1;

                % - prefix
                flags.prefix = 'w';
                if job.preserve, flags.prefix = ['m' flags.prefix]; end
                if job.fwhm>0, flags.prefix = ['s' flags.prefix]; end
            else
                logging.error('No transformation specified!')
            end

            flags = structUpdate(flags,getSetting(rap,'write'),'Mode','update');
            flags.bb = reshape(flags.bb,2,3);

            % find out what streams we should normalise
            streams = {rap.tasklist.currenttask.outputstreams.name};
            for streamInd = 1:numel(streams)
                if iscell(streams{streamInd}), streams{streamInd} = streams{streamInd}{end}; end % renamed -> used original
                imgs = getFileByStream(rap,rap.tasklist.currenttask.domain,indices,regexprep(streams{streamInd},'normalised.*(?=_)','native')); imgs0 = imgs;
                if isstruct(imgs), imgs = cellstr(char(struct2cell(imgs))); end

                % delete previous because otherwise nifti write routine doesn't
                % save disc space when you reslice to a coarser voxel
                for c = 1:numel(imgs)
                    thisfile = spm_file(imgs{c},'prefix',flags.prefix);
                    if exist(thisfile,'file'), delete(thisfile); end
                end

                % apply transformation
                if hasStream(rap,'forward_deformationfield')
                    switch spm('ver')
                        case 'SPM8'
                            job.ofname = '';
                            job.fnames = imgs;
                            job.savedir.saveusr{1} = getPathByDomain(rap,rap.tasklist.currenttask.domain,indices);
                            job.interp = flags.interp;
                            job.comp{1}.def = trans;
                            spm_defs(job);
                        case {'SPM12b' 'SPM12'}
                            job.subj.def = trans;
                            job.subj.resample = imgs;
                            job.woptions = flags;
                            spm_run_norm(job);
                        otherwise
                            logging.error('%s requires SPM8 or later.', mfilename);
                    end
                elseif hasStream(rap,'darteltemplate')
                    job.data.subj.images = imgs;
                    spm_dartel_norm_fun(job);
                end
                wimgs = spm_file(imgs,'prefix',flags.prefix);

                % binarise if specified
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

                % describe outputs
                if isstruct(imgs0)
                    wimgs = struct;
                    for f = fieldnames(imgs0)'
                        wimgs.(f{1}) = spm_file(imgs0.(f{1}),'prefix',flags.prefix);
                    end
                end
                putFileByStream(rap,rap.tasklist.currenttask.domain,indices,streams{streamInd},wimgs);

            end

            % diagnostic
            cfgDiag = getSetting(rap,'diagnostic');
            if isempty(cfgDiag) ||... % do it by default
                (~isstruct(cfgDiag) && cfgDiag) ||... % general
                (isstruct(cfgDiag) && cfgDiag.streamInd)
                streamToReport = {rap.tasklist.currenttask.outputstreams.name};
                for s = 1:numel(streamToReport)
                    if iscell(streamToReport{s}), streamToReport{s} = streamToReport{s}{end}; end % renamed -> used original
                    if contains(streamToReport{s},'segmentations'), content{s} = {'GM'};
                    else, content{s} = {};
                    end
                end
                if isstruct(cfgDiag) && cfgDiag.streamInd
                    streamToReport = streamToReport(cfgDiag.streamInd);
                end
                for s = 1:numel(streamToReport)
                    img = getFileByStream(rap,rap.tasklist.currenttask.domain,indices,streamToReport{s},'content',content{s});
                    if isstruct(img), img = img.(content{s}{1}); end
                    fnImg{s} = spm_file(img{1},'number',',1');
                end
                Timg = rap.directoryconventions.SPMT1;
                if ~exist(Timg,'file'), Timg = fullfile(spm('dir'), Timg); end
                if ~exist(Timg,'file'), logging.error('Couldn''t find template T1 image %s.', Timg); end
                Timg = which(Timg);
                registrationCheck(rap,rap.tasklist.currenttask.domain,indices,Timg,fnImg{:});
            end

        case 'checkrequirements'
            rap = passStreams(rap,{'forward_deformationfield'...
                                   'darteltemplate' 'darteltemplatetomni' 'dartelflowfield'...
                                   'native_segmentations'});
            segOutSel = (strcmp({rap.tasklist.currenttask.outputstreams.name},'normalised_segmentations'));
            if any(segOutSel)
                outStreamName = ['normalised' getSetting(rap,'preserve') '_segmentations'];
                rap = renameStream(rap,rap.tasklist.currenttask.name,'output','normalised_segmentations',outStreamName);
                logging.info([rap.tasklist.currenttask.name ' output stream: ''' outStreamName '''']);
            end
    end
end

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

            if hasStream(rap,'forward_deformationfield')
                flags = defaults.normalise.write;
                trans = getFileByStream(rap,'subject',indices(1),'forward_deformationfield');
            else
                logging.error('No transformation specified!')
            end

            flags = structUpdate(flags,getSetting(rap,'write'),'Mode','update');
            flags.bb = reshape(flags.bb,2,3);

            % find out what streams we should normalise
            streams = {rap.tasklist.currenttask.outputstreams.name};
            for streamInd = 1:numel(streams)
                P = getFileByStream(rap,rap.tasklist.currenttask.domain,indices,streams{streamInd});

                % delete previous because otherwise nifti write routine doesn't
                % save disc space when you reslice to a coarser voxel
                for c = 1:numel(P)
                    thisfile = spm_file(P{c},'prefix',flags.prefix);
                    if exist(thisfile,'file'), delete(thisfile); end
                end

                % apply transformation
                if hasStream(rap,'forward_deformationfield')
                    switch spm('ver')
                        case 'SPM8'
                            job.ofname = '';
                            job.fnames = P;
                            job.savedir.saveusr{1} = getPathByDomain(rap,rap.tasklist.currenttask.domain,indices);
                            job.interp = flags.interp;
                            job.comp{1}.def = trans;
                            spm_defs(job);
                        case {'SPM12b' 'SPM12'}
                            job.subj.def = trans;
                            job.subj.resample = P;
                            job.woptions = flags;
                            spm_run_norm(job);
                        otherwise
                            logging.error('%s requires SPM8 or later.', mfilename);
                    end
                end
                wimgs = spm_file(P,'prefix',flags.prefix);

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
                putFileByStream(rap,rap.tasklist.currenttask.domain,indices,streams{streamInd},wimgs);

            end

            % diagnostic
            cfgDiag = getSetting(rap,'diagnostic');
            if isempty(cfgDiag) ||... % do it by default
                (~isstruct(cfgDiag) && cfgDiag) ||... % general
                (isstruct(cfgDiag) && cfgDiag.streamInd)
                streamToReport = {rap.tasklist.currenttask.outputstreams.name};
                if isstruct(cfgDiag) && cfgDiag.streamInd
                    streamToReport = streamToReport(cfgDiag.streamInd);
                end
                fnImg = spm_file(cellfun(@(s) char(getFileByStream(rap,rap.tasklist.currenttask.domain,indices,s)), streamToReport,'UniformOutput',false),'number',',1');
                registrationCheck(rap,rap.tasklist.currenttask.domain,indices,'structural',fnImg{:});
            end

        case 'checkrequirements'
            rap = passStreams(rap,{'structural' 'forward_deformationfield'});
    end
end

function rap = normwrite(rap,command,varargin)

    switch command
        case 'report'
    %        subj = varargin{1};
    %        if nargin == 4
    %            sess = varargin{2};
    %            localpath = aas_getpath_bydomain(rap,rap.tasklist.currenttask.domain,[subj,sess]);
    %        else % subject
    %            localpath = aas_getpath_bydomain(rap,'subject',subj);
    %        end
    %
    %        % find out what streams we should normalise
    %		streams=aas_getstreams(rap,'output');
    %        if isfield(rap.tasklist.currenttask.settings,'diagnostic') && isstruct(rap.tasklist.currenttask.settings.diagnostic)
    %            inds = rap.tasklist.currenttask.settings.diagnostic.streamInd;
    %        else
    %            inds = 1:length(streams);
    %        end
    %        % determine normalised struct
    %        [inp, inpattr] = aas_getstreams(rap,'input');
    %        streamStruct = inp{cellfun(@(a) isfield(a,'diagnostic') && a.diagnostic, inpattr)}; streamStruct = strsplit(streamStruct,'.');
    %        structdiag = aas_getfiles_bystream_dep(rap,'subject',varargin{1},streamStruct{end});
    %        if size(structdiag,1) > 1
    %            sname = basename(structdiag);
    %            structdiag = structdiag((sname(:,1)=='w') | (sname(:,2)=='w'),:);
    %            if isempty(structdiag) % probably due to structural input-output
    %                structdiag = rap.directory_conventions.T1template;
    %                if ~exist(structdiag,'file'), structdiag = fullfile(spm('Dir'),structdiag); end
    %                structdiag = which(structdiag);
    %            end
    %        end
    %        for streamInd = inds
    %            streamfn = aas_getfiles_bystream(rap,rap.tasklist.currenttask.domain,cell2mat(varargin),streams{streamInd},'output');
    %            streamfn = streamfn(1,:);
    %            streamfn = strtok_ptrn(basename(streamfn),'-0');
    %            fn = ['diagnostic_aas_checkreg_slices_' streamfn '_1.jpg'];
    %            if ~exist(fullfile(localpath,fn),'file')
    %                aas_checkreg(rap,rap.tasklist.currenttask.domain,cell2mat(varargin),streams{streamInd},structdiag);
    %            end
    %            % Single-subject
    %            fdiag = dir(fullfile(localpath,'diagnostic_*.jpg'));
    %            for d = 1:numel(fdiag)
    %                rap = aas_report_add(rap,subj,'<table><tr><td>');
    %                imgpath = fullfile(localpath,fdiag(d).name);
    %                rap=aas_report_addimage(rap,subj,imgpath);
    %                [p, f] = fileparts(imgpath); avipath = fullfile(p,[strrep(f(1:end-2),'slices','avi') '.avi']);
    %                if exist(avipath,'file'), rap=aas_report_addimage(rap,subj,avipath); end
    %                rap = aas_report_add(rap,subj,'</td></tr></table>');
    %            end
    %            % Study summary
    %            rap = aas_report_add(rap,'reg',...
    %                ['Subject: ' basename(aas_getsubjpath(rap,subj)) '; Session: ' aas_getdirectory_bydomain(rap,rap.tasklist.currenttask.domain,varargin{end}) ]);
    %            rap=aas_report_addimage(rap,'reg',fullfile(localpath,fdiag(1).name));
    %        end
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
%                    if exist(thisfile,'file'), delete(thisfile); end
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
%                            spm_run_norm(job);
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

                % describe outputs with diagnostic
                putFileByStream(rap,rap.tasklist.currenttask.domain,indices,streams{streamInd},wimgs);

                if ~isfield(rap.tasklist.currenttask.settings,'diagnostic') ||... % do it by default
                        (~isstruct(rap.tasklist.currenttask.settings.diagnostic) && rap.tasklist.currenttask.settings.diagnostic) ||... % general
                        (isstruct(rap.tasklist.currenttask.settings.diagnostic) && streamInd == rap.tasklist.currenttask.settings.diagnostic.streamInd) % selective
                    registrationCheck(rap,rap.tasklist.currenttask.domain,indices,'structural',spm_file(wimgs{1},'number',',1'));
                end
            end

        case 'checkrequirements'
            in = {rap.tasklist.currenttask.inputstreams.name}; in = setdiff(in,{'structural' 'forward_deformationfield'});
            out = {rap.tasklist.currenttask.outputstreams.name}; if ~iscell(out), out = {out}; end
            for s = 1:numel(in)
                instream = strsplit(in{s},'.'); instream = instream{end};
                if s <= numel(out)
                    if ~strcmp(out{s},instream)
                        rap = renameStream(rap,rap.tasklist.currenttask.name,'output',out{s},instream);
                        logging.info([rap.tasklist.currenttask.name ' output stream: ''' instream '''']);
                    end
                else
                    rap = renameStream(rap,rap.tasklist.currenttask.name,'output','append',instream);
                    logging.info([rap.tasklist.currenttask.name ' output stream: ''' instream '''']);
                end
            end
    end
end

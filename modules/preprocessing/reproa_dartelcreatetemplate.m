function rap = reproa_dartelcreatetemplate(rap,command)

switch command
    case 'doit'
        % retrieve external template (if any)
        template = '';
        if hasStream(rap,'study',[],'darteltemplate'), template = getFileByStream(rap,'study',[],'darteltemplate'); end

        % collect images
        imgAll{1} = cell(1,getNByDomain(rap,'subject'));
        imgAll{2} = cell(1,getNByDomain(rap,'subject'));
        for subj = 1:getNByDomain(rap,'subject')
            seg = getFileByStream(rap, 'subject',subj, 'dartelimported_segmentations','content',{'GM' 'WM'});
            imgAll{1}(subj) = seg.GM;
            imgAll{2}(subj) = seg.WM;
        end
        toExcl = cellfun(@(s) any(strcmp(getSetting(rap,'exclude'),s)), {rap.acqdetails.subjects.subjname});
        imgTemplate{1} = imgAll{1}(~toExcl);
        imgTemplate{2} = imgAll{2}(~toExcl);
        imgNoTemplate{1} = imgAll{1}(toExcl);
        imgNoTemplate{2} = imgAll{2}(toExcl);

        % Set up job
        % - parse defaults
        cfg = tbx_cfg_dartel;
        % - rearrange spm_mod
        modDir = fullfile(spm_file(which('spmClass'),'path'),'spm_mods');
        if exist(modDir,'dir')
            addpath(modDir);
        end

        cfgReq = {'param' 'optim'};
        cfgTag = cellfun(@(v) v.tag, cfg.values{2}.val{2}.val, 'UniformOutput',false);
        cfgCheck = ismember(cfgReq,cfgTag);
        if ~all(cfgCheck), logging.error('Defaults for parameters%s not found',sprintf(' "%s"',cfgReq{~cfgCheck})); end

        cfgParam = cfg.values{2}.val{2}.val{strcmp(cfgTag,'param')};
        for it = 1:numel(cfgParam.val) % for each iteration
            for par = 1:numel(cfgParam.val{1}.val) % for each parameter
                param(it).(cfgParam.val{1}.val{par}.tag) = cfgParam.val{it}.val{par}.val{1};
            end
        end
        cfgOptim = cfg.values{2}.val{2}.val{strcmp(cfgTag,'optim')};
        for par = 1:numel(cfgOptim.val) % for each parameter
            optim(it).(cfgOptim.val{par}.tag) = cfgOptim.val{par}.val{1};
        end

        % - parse settings
        [val,~,attr] = getSetting(rap,'rform');
        settings = struct('template', 'Template', 'rform', find(strcmp(strsplit(attr.options,'|'),val))-1,...
                          'param', param,...
                          'optim', optim);

        % Create template
        if ~isempty(imgTemplate{1})
            spm_dartel_template(struct('images', {imgTemplate}, 'settings', settings));

            % - template in first subject
            template = cellstr(spm_select('FPListRec', getPathByDomain(rap,'subject',1), '^Template_[1-6]\.nii$'));
        end

        % Warp excluded subjects
        if ~isempty(imgNoTemplate{1})
            settings = rmfield(settings,'template');
            for t = 1:6
               settings.param(t).template = template(t);
            end
            out = spm_dartel_warp(struct('images', {imgNoTemplate}, 'settings', settings));
            for f = 1:numel(out.files)
                movefile(out.files{f},strrep(out.files{f},'.nii','_Template.nii'),'f');
            end
        end

        % Output
        % - flow fields
        for subj = 1:getNByDomain(rap,'subject')
            putFileByStream(rap, 'subject',subj, 'dartelflowfield', ...
                            spm_select('FPListRec', getPathByDomain(rap,'subject',subj), '^u_.*_Template\.nii$'));
        end

        % - template
        templateToStream = spm_file(template{6},'path',getPathByDomain(rap,'study',[]));
        movefile(template{6},templateToStream);
        putFileByStream(rap, 'study',[], 'darteltemplate', templateToStream);

        % - normalisation XFM
        stages = fieldnames(rap.tasksettings);
        tpm = getSetting(setCurrenttask(rap,'task',getSourceTaskInd(rap,'reproa_segment')),'segmentation.tpm');
        affine = spm_get_space(tpm)/spm_klaff(nifti(templateToStream),tpm);
        xfm = affine/spm_get_space(templateToStream);
        fnXFM = fullfile(getPathByDomain(rap,'study',[]),'dartel_templatetomni_xfm.mat');
        save(fnXFM,'xfm')
        putFileByStream(rap, 'study',[], 'darteltemplatetomni', fnXFM);

    case 'checkrequirements'
        if hasStream(rap,'study',[],'darteltemplate')
            logging.info('External template will be used');
            rap.tasksettings.reproa_dartelcreatetemplate(rap.tasklist.currenttask.index).exclude = {rap.acqdetails.subjects.subjname};
        end
end
end

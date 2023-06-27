function rap = reproa_dartelcreatetemplate(rap,command)

switch command
    case 'doit'
        % retrieve external template (if any)
        template = '';
        if hasStream(rap,'study',[],'darteltemplate'), template = getFileByStream(rap,'study',[],'darteltemplate'); end

        % collect images
        imgAll{1} = cell(1,getNByDomain(rap,'subject'));
        imgAll{2} = cell(1,getNByDomain(rap,'subject'));
        for subjind = 1:getNByDomain(rap,'subject')
            seg = getFileByStream(rap, 'subject',subjind, 'dartelimported_segmentations','content',{'GM' 'WM'});
            imgAll{1}(subjind) = seg.GM;
            imgAll{2}(subjind) = seg.WM;
        end
        toExcl = cellfun(@(s) any(strcmp(getSetting(rap,'exclude'),s)), {rap.acqdetails.subjects.subjname});
        imgTemplate{1} = imgAll{1}(~toExcl);
        imgTemplate{2} = imgAll{2}(~toExcl);
        imgNoTemplate{1} = imgAll{1}(toExcl);
        imgNoTemplate{2} = imgAll{2}(toExcl);

        % Set up job
        % - parse defaults
        cfg = tbx_cfg_dartel;
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

        % create template
        if ~isempty(imgTemplate{1})
            spm_dartel_template(struct('images', {imgTemplate}, 'settings', settings));

            % (template in first subject)
            for t = 1:6
               template(t,:) = spm_select('fplist', fileparts(imgTemplate{1}{1}), sprintf('Template_%d',t));
            end
        end

        % warp excluded subjects
        if ~isempty(imgNoTemplate{1})
            settings = rmfield(settings,'template');
            for t = 1:6
               settings.param(t).template = {template(t,:)};
            end
            out = spm_dartel_warp(struct('images', {imgNoTemplate}, 'settings', settings));
            for f = 1:numel(out.files)
                movefile(out.files{f},strrep(out.files{f},'.nii','_Template.nii'),'f');
            end
        end

        % template
        rap = aas_desc_outputs(rap, 'dartel_template', template(6,:));

        % normalisation XFM
        fname_template = aas_getfiles_bystream(rap,'study',[],'dartel_template','output');
        stages = fieldnames(rap.tasksettings);
        tpm = rap.tasksettings.(stages{find(cellfun(@(x) ~isempty(regexp(x,'^aamod_segment.*','match')), stages),1,'first')}).tpm;
        affine = spm_get_space(tpm)/spm_klaff(nifti(fname_template),tpm);
        xfm = affine/spm_get_space(fname_template);
        fname_xfm = fullfile(aas_getstudypath(rap),'dartel_templatetomni_xfm.mat');
        save(fname_xfm,'xfm')
        rap = aas_desc_outputs(rap, 'dartel_templatetomni_xfm', fname_xfm);

        % normalised template
        Vt = spm_file_split(spm_vol(fname_template),aas_getstudypath(rap)); % --> Template_6-0_00001.nii (GM) and Template_6-0_00002.nii (WM)

        spm_get_space(Vt(1).fname,xfm*spm_get_space(Vt(1).fname));
        fname_ngrey = spm_file(Vt(1).fname,'prefix',rap.spm.defaults.normalise.write.prefix);
        spm_smooth(Vt(1).fname,fname_ngrey,[0 0 0]);
        rap = aas_desc_outputs(rap, 'normalised_dartel_template_grey', fname_ngrey);

        spm_get_space(Vt(2).fname,xfm*spm_get_space(Vt(2).fname));
        fname_nwhite = spm_file(Vt(2).fname,'prefix',rap.spm.defaults.normalise.write.prefix);
        spm_smooth(Vt(2).fname,fname_nwhite,[0 0 0]);
        rap = aas_desc_outputs(rap, 'normalised_dartel_template_white', fname_nwhite);

        % flow fields
        for subjind = 1:length(rap.acqdetails.subjects)
            pth = fileparts(imgAll{1}{subjind});
            flowimg = spm_select('fplist', pth, '^u_');
            rap = aas_desc_outputs(rap, subjind, 'dartel_flowfield', flowimg);
        end
    case 'checkrequirements'
        if hasStream(rap,'study',[],'darteltemplate')
            logging.info('External template will be used');
            rap.tasksettings.reproa_dartelcreatetemplate(rap.tasklist.currenttask.index).exclude = {rap.acqdetails.subjects.subjname};
        end
end
end

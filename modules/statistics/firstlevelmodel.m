function rap = firstlevelmodel(rap,command,subj)

switch command
    case 'report' % [TA]
%        if ~exist(fullfile(aas_getsubjpath(rap,subj),'diagnostic_aamod_firstlevel_model_design.jpg'),'file')
%            load(aas_getfiles_bystream(rap,subj,rap.tasklist.currenttask.outputstreams.stream{1}));
%            spm_DesRep('DesOrth',SPM.xX);
%            saveas(spm_figure('GetWin','Graphics'),fullfile(aas_getsubjpath(rap,subj),'diagnostic_aamod_firstlevel_model_design.jpg'));
%            close all;
%        end
%        fdiag = dir(fullfile(aas_getsubjpath(rap,subj),'diagnostic_*.jpg'));
%        for d = 1:numel(fdiag)
%            rap = aas_report_add(rap,subj,'<table><tr><td>');
%            rap=aas_report_addimage(rap,subj,fullfile(aas_getsubjpath(rap,subj),fdiag(d).name));
%            rap = aas_report_add(rap,subj,'</td></tr></table>');
%        end

    case 'doit'
        %% Init
        % Toolboxes
        global reproacache
        % - update SPM defaults
        tSPM = reproacache('toolbox.spm');
        tSPM.reload(true);

        % - rWLS
        if strcmp(getSetting(rap,'autocorrelation'),'wls')
            rWLS = reproacache('toolbox.rwls');
            rWLS.load;
        end

        % We can have missing runs, so we're going to use only the runs that are common to this subject and selectedruns
        [numRuns, runInds] = getNByDomain(rap,'fmrirun',subj);

        %% Prepare images and models
        files = cell(numRuns,1);
        model = cell(numRuns,1);
        modelC = cell(numRuns,1);

        sliceOrder = [];
        refSlice = [];

        for run = 1:numRuns
            % Images and timings
            fns = getFileByStream(rap,'fmrirun',[subj runInds(run)],'fmri');
            V = spm_vol(fns{1});
            files{run} = arrayfun(@(n) spm_file(fns,'number',[',' num2str(V(n).n(1))]), 1:numel(V));
            headerFn = getFileByStream(rap,'fmrirun',[subj runInds(run)],'fmri_header');
            load(headerFn{1},'header');
            if run == 1, TR = header{1}.volumeTR;
            else
                if TR ~= header{1}.volumeTR, logging.error('Run %d has different TR from earlier runs, they can''t be in the same model.',rap.acqdetails.fmriruns(runInds(run)).name); end
            end
            if hasStream(rap,'fmrirun',[subj runInds(run)],'sliceorder')
                sliceFn = getFileByStream(rap,'fmrirun',[subj runInds(run)],'sliceorder');
                slicetiming = load(sliceFn{1});
                if isempty(sliceOrder)
                    sliceOrder = slicetiming.sliceOrder;
                    refSlice = slicetiming.refSlice;
                else
                    if ~isequal(sliceOrder, slicetiming.sliceOrder), logging.error('Run %d has different slice order from earlier runions, they can''t be in the same model.',rap.acqdetails.fmriruns(runInds(run)).name); end
                end
            end

            % Models
            model{run} = getSetting(rap,'model','fmrirun',[subj run]);
            if ~isempty(model{run}), model{run} = model{run}.event; end
            modelC{run} = getSetting(rap,'modelC','fmrirun',[subj run]);
            if ~isempty(modelC{run}), modelC{run} = modelC{run}.covariate; end

            % - check that we have at least one model of each
            if (numel(model{run})>1) || (numel(modelC{run})>1)
                logging.error('Error while getting model details as more than one specification for subject %s run %s',subjname,rap.acqdetails.fmriruns(runInds(run)).name);
            end
            if isempty(model{run}) && isempty(modelC{run})
                logging.warning('Cannot find model specification for subject %s run %s',subjname,rap.acqdetails.fmriruns(runInds(run)).name);
            end

            % Nuisance regressors
            xml = readModule('firstlevelmodel.xml');
            schema = xml.settings.modelC.covariate;

            % - realignment parameter
            if any(any(getSetting(rap,'includerealignmentparameters'))) && hasStream(rap,'fmrirun',[subj runInds(run)],'realignment_parameter')
                movRegNames = {'x' 'y' 'z' 'r' 'p' 'j'};
                fn = getFileByStream(rap,'fmrirun',[subj runInds(run)], 'realignment_parameter');
                rp = load(fn{1}); % expect text file
                movMat = getSetting(rap,'includerealignmentparameters');
                for o = 1:size(movMat,1)
                    for d = 1:size(movMat,2)
                        if movMat(o,d)
                            regNameFormat = ['%s^' num2str(o)];
                            movReg = rp.^o;
                            for i = 2:d
                                if d < size(movMat,2) % gradient/derivative
                                    regNameFormat = ['g(' regNameFormat ')'];
                                    movReg = gradient(movReg);
                                else % spin history
                                    regNameFormat = ['sh(' regNameFormat ')'];
                                    movReg = [zeros(1,size(movReg,2)); diff(movReg)];
                                end
                            end
                            for b = 1:min(numel(movRegNames),size(movReg,2))
                                modelC{run}(end+1) = schema;
                                modelC{run}(end).name = sprintf(regNameFormat,movRegNames{b});
                                modelC{run}(end).vector = movReg(:,b);
                                modelC{run}(end).HRF = false;
                                modelC{run}(end).interest = false;
                            end
                        end
                    end
                end
            end

            % - compartment regressors
            if ~isempty(getSetting(rap,'includecompartmentsignal')) && hasStream(rap,'fmrirun',[subj runInds(run)],'compartment_signal')
                CNames = {'GM', 'WM', 'CSF', 'OOH'};
                fn = getFileByStream(rap,'fmrirun',[subj runInds(run)], 'compartment_signal');
                for c = getSetting(rap,'includecompartmentsignal')
                    % containes signal
                    signal = load(fn{c}); % expect text file
                    modelC{run}(end+1) = schema;
                    modelC{run}(end).name = CNames{c};
                    modelC{run}(end).vector = signal;
                    modelC{run}(end).HRF = false;
                    modelC{run}(end).interest = false;
                end
            end

            % - spikes
            if getSetting(rap,'includespikes') && hasStream(rap,'fmrirun',[subj runInds(run)],'spikes')
                fn = getFileByStream(rap,'fmrirun',[subj runInds(run)],'spikes');

                % Contains spike scan numbers
                spikes = struct2cell(load(fn{1})); % expect mat-file with a struct with fields for different types of spikes
                spikes = union(spikes{:});
                for s = spikes
                    vec = zeros(1,numel(files{run})); vec(s) = 1;
                    modelC{run}(end+1) = schema;
                    modelC{run}(end).name = sprintf('SpikeMov%03d', s);
                    modelC{run}(end).vector = vec;
                    modelC{run}(end).HRF = false;
                    modelC{run}(end).interest = false;
                end
            end

            % - denoising
            if getSetting(rap,'includedenoising') && hasStream(rap,'fmrirun',[subj runInds(run)],'denoising_regressors')
                fn = getFileByStream(rap,'fmrirun',[subj runInds(run)],'denoising_regressors');
                regressors = load(fn{1}); % expect text file
                for r = 1:size(regressors,2)
                    modelC{run}(end+1) = schema;
                    modelC{run}(end).name = sprintf('Denoising%02d', r);
                    modelC{run}(end).vector = regressors(:,r);
                    modelC{run}(end).HRF = false;
                    modelC{run}(end).interest = false;
                end
            end
        end

        %% Prepare SPM
        defSPM = spm_get_defaults('stats.fmri');
        SPM = [];
        SPM.xY.RT = TR;
        if getSetting(rap,'globalscaling'), SPM.xGX.iGXcalc = 'scaling';
        else, SPM.xGX.iGXcalc = 'none';
        end
        SPM.xVi.form = getSetting(rap,'autocorrelation');
        SPM.nscan = cellfun(@numel, files);

        % basis functions
        SPM.xBF.T          = defSPM.t;          % number of time bins per scan
        SPM.xBF.T0         = [];                % time of reference
        SPM.xBF.UNITS      = 'scans';           % OPTIONS: 'scans'|'secs' for onsets
        SPM.xBF.Volterra   = 1;                 % OPTIONS: 1|2 = order of convolution
        SPM.xBF.name       = 'hrf';
        SPM.xBF.length     = defSPM.hrf(7);     % length in seconds
        SPM.xBF.order      = 1;                 % order of basis set

        % Collect values from the .xml or user script
        SPM.xBF = structUpdate(SPM.xBF,getSetting(rap,'xBF'),'ignoreEmpty',true);

        % If a non-SPM BF name is used, let's load a custom BFs
        % - possible SPM basis functions (based on spm_get_bf.m 7654)
        SPM_BFs = {...
            'hrf', ...
            'hrf (with time derivative)', ...
            'hrf (with time and dispersion derivatives)', ...
            'Fourier set', ...
            'Fourier set (Hanning)', ...
            'Gamma functions', ...
            'Finite Impulse Response'...
            };
        if ~any(strcmp(SPM.xBF.name, SPM_BFs))
            dt = TR/xBF.T;

            if ~exist(SPM.xBF.name), logging.error('Cannot find custom basis funtion definition file %s', SPM.xBF.name); end
            load(SPM.xBF.name, 'customBF');
            if ~equal(fieldnames(customBF)',{'fs' 'bf'}), logging.error('Custom basis funtion definition MUST (only) contain fields ''fb'' and ''bs'''); end

            SPM.xBF.name = spm_file(SPM.xBF.name,'basename');

            % re-sample at dt
            hrfLen = size(customBF.bf,1) * customBF.fs;
            tcBF = 0:customBF.fs:hrfLen; tcBF(end) = [];
            txBF = 0:dt:hrfLen; txBF(end) = [];
            bf = [];
            for b = 1:size(customBF.bf,2)
                bf = [bf interp1(tcBF, customBF.bf(:,b), txBF, 'linear', 'extrap')'];
            end

            % orthogonalise and fill in basis function structure
            SPM.xBF.bf  =  spm_orth(bf);
        end

        % Slicing times
        if isempty(SPM.xBF.T0) % allow T0 override in .xml, or settings
            if ~isempty(sliceOrder)
                refwhen = find(sliceOrder==refSlice)/numel(sliceOrder);
                SPM.xBF.T = numel(sliceOrder);
            else
                % otherwise, default to halfway through the volume
                logging.warning('No stream sliceorder found, defaulting timing to SPM.xBF.T0 to halfway through a volume.');
                refwhen = 0.5;
            end
            SPM.xBF.T0 = round(SPM.xBF.T*refwhen);
        end
        SPM.xBF.dt = SPM.xY.RT / SPM.xBF.T; % Time bin length in secs

        % Analysis directory
        SPM.swd = fullfile(getPathByDomain(rap,'subject',subj), rap.directoryconventions.statsdirname);
        dirMake(SPM.swd);

        %% Set up model
        xBF = SPM.xBF;
        if ~isfield(xBF,'bf') || isempty(xBF.bf)
            xBF = [];
            xBF.dt = SPM.xY.RT;
            xBF.name = SPM.xBF.name;
            xBF.length = SPM.xBF.length;
            xBF.order = SPM.xBF.order;
            xBF = spm_get_bf(xBF);
        end
        rInterest = [];
        rNuisance = [];
        rInd = 0;

        for run = 1:numRuns
            SPM.xX.K(run).HParam = getSetting(rap,'highpassfilter');

            % Add events
            SPM.Sess(run).U = struct('ons',{},...
                'dur',{},...
                'name',{{}},...
                'P',{},...
                'orth',[]...
                );
            for c = 1:numel(model{run});
                if isempty(model{run}(c).modulation)
                    modulation = struct('name','none');
                    parLen = 0;
                else
                    modulation = model{run}(c).modulation;
                    parLen = length(modulation);

                    % - scale temporal modulation
                    tModsToScale = find(strcmp({modulation.name},'time_toScale'));
                    if ~isempty(tModsToScale)
                        switch SPM.xBF.UNITS
                            case 'secs', sf = 1/60;
                            case 'scans', sf = SPM.xY.RT/60;
                            otherwise, logging.error('Unknown UNIT "%s".',SPM.xBF.UNITS);
                        end
                        for p = tModsToScale
                            modulation(p).P = modulation(p).P*sf;
                        end
                    end
                end

                SPM.Sess(run).U(c) = struct(...
                    'ons', model{run}(c).ons,...
                    'dur', model{run}(c).dur,...
                    'name', {{model{run}(c).name}},...
                    'P',modulation,...
                    'orth', 1);

                % - orthogonalise?
                if strcmp(spm('Ver'),'SPM12') && ~isempty(getSetting(rap,'orthogonalisation')) && ~getSetting(rap,'orthogonalisation')
                    SPM.Sess(run).U(c).orth = 0;
                end

                rInterest = [rInterest rInd+[1:(1+parLen)*size(xBF.bf,2)]];
                rInd = rInd+(1+parLen)*size(xBF.bf,2);
            end

            % Add covariates
            SPM.Sess(run).C.C = [];
            SPM.Sess(run).C.name = {};

            for c = 1:numel(modelC{run})
                SPM.Sess(run).C.name = [SPM.Sess(run).C.name ...
                    modelC{run}(c).name];

                covVect = modelC{run}(c).vector;
                if modelC{run}(c).HRF > 0 % convolve with HRF?
                    U =[];
                    U.u = covVect(:);
                    U.name = {modelC{run}(c).name};
                    covVect = spm_Volterra(U, xBF.bf);
                end
                SPM.Sess(run).C.C = [SPM.Sess(run).C.C covVect];

                rInd = rInd + 1;
                if modelC{run}(c).interest > 0
                    rInterest = [rInterest rInd];
                else
                    rNuisance = [rNuisance rInd];
                end
            end
        end

        SPM.xY.P = char(cat(1,files{:}));
        if getSetting(rap,'firstlevelmasking') < 1, spm_get_defaults('mask.thresh',getSetting(rap,'firstlevelmasking')); end

        cd(SPM.swd);
        if strcmp(getSetting(rap,'autocorrelation'),'wls')
            SPM = spm_rwls_fmri_spm_ui(SPM);
        else
            SPM = spm_fmri_spm_ui(SPM);
        end

        SPM.xX.X = double(SPM.xX.X);
        SPM.xX.iG = rNuisance;
        SPM.xX.iC = rInterest;

        % Turn off masking if requested
        if ~getSetting(rap,'firstlevelmasking'), SPM.xM = -inf(size(SPM.xX.X,1),1); end

        % Correct epmty model for sphericity check
        if isempty([SPM.Sess.U])
            SPM.xX.W  = sparse(eye(size(SPM.xY.P,1)));
            SPM.xVi.V = sparse(eye(size(SPM.xY.P,1)));
        end

        %% Estimate model
        % Avoid overwrite dialog
        prevmask = spm_select('List',SPM.swd,'^mask\..{3}$');
        if ~isempty(prevmask)
            for ind = 1:size(prevmask,1)
                spm_unlink(fullfile(SPM.swd, prevmask(ind,:)));
            end
        end

        % Estimate
        if strcmp(getSetting(rap,'autocorrelation'),'wls')
            SPM = spm_rwls_spm(SPM);
        else
            SPM = spm_spm(SPM);
        end

        % Saving Residuals
        if ~isempty(getSetting(rap,'writeresiduals'))
            logging.info('Writing residuals...');
            iC = getSetting(rap,'writeresiduals'); if ischar(iC), iC = NaN; end
            VRes = spm_write_residuals(SPM,iC);
            for run = 1:numel(SPM.nscan)
                runPath = getPathByDomain(rap,'fmrirun',[subj, runInds(run)]);
                fres = {VRes(sum(SPM.nscan(1:run-1))+1:sum(SPM.nscan(1:run))).fname}';
                spm_file_merge(fres,fullfile(runPath,sprintf('Res-%02d.nii',runInds(run))),0,SPM.xY.RT);
                cellfun(@delete, fres);
                putFileByStream(rap,'fmrirun',[subj runInds(run)],'fmri',spm_file(fres,'path',runPath));
            end
            logging.info('\tDone.');
        end

        %% Describe outputs
        putFileByStream(rap,'subject',subj,'firstlevel_spm',fullfile(SPM.swd,'SPM.mat'));
        putFileByStream(rap,'subject',subj,'firstlevel_betas',spm_file({SPM.Vbeta.fname},'path',SPM.swd));
        putFileByStream(rap,'subject',subj,'firstlevel_msres',spm_file(SPM.VResMS.fname,'path',SPM.swd));
        if getSetting(rap,'firstlevelmasking')
            putFileByStream(rap,'subject',subj,'firstlevel_brainmask',spm_file(SPM.VM.fname,'path',SPM.swd));
            registrationCheck(rap,'subject',subj,files{1}{1},'firstlevel_brainmask','prefix','_mask');
        end

        %% Diagnostics
        % Design
        spm_DesRep('DesOrth',SPM.xX);
        h = spm_figure('GetWin', 'Graphics');
        set(h,'Renderer','opengl');
        % the following is a workaround for font rescaling weirdness
        set(findall(h,'Type','text'),'FontSize', 10);
        set(findall(h,'Type','text'),'FontUnits','normalized');
        print(h,'-djpeg','-r150', fullfile(getPathByDomain(rap,'subject',subj), ['diagnostic_' rap.tasklist.currenttask.name '_design.jpg']));
        spm_figure('Close','Graphics');

        fid = fopen(fullfile(getPathByDomain(rap,'subject',subj), ['diagnostic_' rap.tasklist.currenttask.name '_design_regressors.txt']),'w');
        cellfun(@(r) fprintf(fid,'%s\n', r), SPM.xX.name);
        fclose(fid);

        % Betas and regressors
        if numel(SPM.xX.iC) > 1
            if getSetting(rap,'firstlevelmasking')
               mask = logical(spm_read_vols(SPM.VM));
            end
            SPMcols = SPM.xX.iC;
            expPoly = cellfun(@(x) ~isempty(regexp(x,'.*\^[2-9]\*.*')), SPM.xX.name);
            origEVs = SPM.xX.name(~expPoly);
            origX = SPM.xX.X(:,~expPoly);
            origBeta = SPM.Vbeta(~expPoly);

            SPMmodel = origX(:, SPM.xX.iC);
            hRegs = corrTCs(SPMmodel, origEVs(SPM.xX.iC));

            for d = 1:numel(SPMcols)
                Y = spm_read_vols(origBeta(SPMcols(d)));
                % maskVol things we don't want...
                if getSetting(rap,'firstlevelmasking'), Y = Y(mask);
                else, Y = Y(isfinite(Y) & Y~=0);
                end
                if d == 1
                    allBetas = nan(numel(Y), numel(SPMcols));
                end
                allBetas(:,d) = Y;
            end
            hBetas = corrTCs(allBetas, origEVs(SPMcols));

            print(hRegs,'-djpeg','-r150', fullfile(getPathByDomain(rap,'subject',subj), ['diagnostic_' rap.tasklist.currenttask.name '_design_regressors.jpg']));
            print(hBetas,'-djpeg','-r150', fullfile(getPathByDomain(rap,'subject',subj), ['diagnostic_' rap.tasklist.currenttask.name '_design_betas.jpg']));
            close(hRegs)
            close(hBetas)
        end

        % rWLS?
        if strcmp(getSetting(rap,'autocorrelation'),'wls')
            % sometimes rwls looks for the movement params using the wrong
            % filename, so pass in an expliclit fname if we can
            if hasStream(rap,'subject',subj,'realignment_parameter')
                rpFileName = getFileByStream(rap,'subject',subj,'realignment_parameter');
                spm_rwls_resstats(SPM,[],rpFileName);
            else
                spm_rwls_resstats(SPM);
            end

            h = spm_figure('GetWin', 'Graphics');
            set(h,'Renderer','opengl');
            % the following is a workaround for font rescaling weirdness
            set(findall(h,'Type','text'),'FontSize', 10);
            set(findall(h,'Type','text'),'FontUnits','normalized');
            print(h,'-djpeg','-r150', fullfile(getPathByDomain(rap,'subject',subj), ['diagnostic_' rap.tasklist.currenttask.name '_rWLS.jpg']));
            spm_figure('Close','Graphics');
            spm_figure('Close','Interactive'); % rWLS toolbox leaves the interactive window up...

            rWLS.unload;
        end

    case 'checkrequirements'
        %% rWLS
        global repproacache
        if strcmp(getSetting(rap,'autocorrelation'),'wls') && ~reproacache.isKey('toolbox.rwls')
            logging.error('rWLS toolbox not found');
        end

        %% Adjust outstream
        if ~getSetting(rap,'firstlevelmasking')
            rap = renameStream(rap,rap.tasklist.currenttask.name,'output','firstlevel_brainmask',[]);
            logging.info('REMOVED: %s output stream: firstlevel_brainmask', rap.tasklist.currenttask.name');
        end
        if isempty(getSetting(rap,'writeresiduals')) && any(strcmp({rap.tasklist.currenttask.outputstreams.name},'fmri'))
            rap = renameStream(rap,rap.tasklist.currenttask.name,'output','fmri',[]);
            logging.info('REMOVED: %s output stream: fmri', rap.tasklist.currenttask.name');
        end
end
end

function h = corrTCs(TCs, TCNames)
    corrTC = corrcoef(TCs, 'rows', 'pairwise');

    % Keep only upper triagonal
    trigon = ~logical(tril(ones(size(corrTC))));
    corrTC(~trigon) = 0;

    % Significance
    dfTC = sum(~isnan(TCs));
    dfTC = min(repmat(dfTC', [1 numel(dfTC)]), repmat(dfTC, [numel(dfTC) 1]));
    tTC = corrTC ./ sqrt((1-corrTC.^2) ./ (dfTC-2));
    pTC = (1 - tcdf(abs(tTC), dfTC-2)) * sum(trigon(:)); % Bonferroni-corrected
    corrTC(pTC>0.05) = 0;

    % Shared variance
    sharedVar = sign(corrTC).*corrTC.^2;
    MsharedVar = mean(abs(sharedVar(sharedVar>0)));

    % Plot
    h = figure;
    set(h, 'Position', [0 0 1200 700])
    imagesc(sharedVar);
    set(gca, 'Xtick', 1:size(corrTC,2), 'Ytick', 1:size(corrTC,1), ...
        'Xticklabel', TCNames, 'XTickLabelRotation', 90,  'Yticklabel', TCNames)
    caxis([-1 1]);
    cmap = jet(128); cmap(64,:) = [1 1 1]; cmap(65,:) = [1 1 1];
    colormap(cmap);
    colorbar;
    title(sprintf('Variance shared by variables. Mean: %0.2f %%', MsharedVar*100))
end

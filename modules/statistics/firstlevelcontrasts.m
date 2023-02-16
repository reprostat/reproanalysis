function rap = firstlevelcontrasts(rap,command,subj)

    switch command
        case 'report'
            reportStore = sprintf('sub%d',subj);
            addReport(rap,reportStore,'<h4>Contrasts</h4>');
            rap = addReportMedia(rap,reportStore,spm_select('FPList',getPathByDomain(rap,'subject',subj),['^diagnostic_' mfilename '.*contrasts\.jpg$']));

            if getSetting(rap,'diagnostics.histogram')
                addReport(rap,reportStore,'<h4>Histograms</h4>');
                for fn = cellstr(spm_select('FPList',getPathByDomain(rap,'subject',subj),['^diagnostic_' mfilename '.*histogram.*\.jpg$']))
                    conName = regexp(fn{1},'(?<=histogram_)[a-zA-Z-_]*','match');
                    addReport(rap,reportStore,['<h5>' conName{1} '</h5>']);
                    rap = addReportMedia(rap,reportStore,fn{1});
                end
            end

        case 'doit'
            %% Init
            cwd = pwd;

            % Load and update SPM
            fnSPM = char(getFileByStream(rap,'subject',subj,'firstlevel_spm'));
            load(fnSPM,'SPM');
            anadir = spm_file(fnSPM,'path');
            SPM.swd = anadir;

            [nRuns, selectedRuns] = getNByDomain(rap, 'fmrirun', subj);
            runNames = {rap.acqdetails.fmriruns(selectedRuns).name};

            % Load up contrasts from task settings
            contrasts = getSetting(rap,'contrast','subject',subj);
            if ~isempty(contrasts), contrasts = contrasts.con; end

            % Add contrasts for each task regressor v baseline?
            if ~strcmp(getSetting(rap,'eachagainstbaseline'),'none')
                switch getSetting(rap,'eachagainstbaseline')
                    case 'eachrun'
                        for cInd = SPM.xX.iC
                            newv = basev;
                            newv(cInd) = 1;
                            contrasts(end+1)= struct(...
                                'format','uniquebyrun',...
                                'vector',newv,...
                                'session',[],...
                                'type','T',...
                                'name',sprintf('%s-o-baseline',SPM.xX.name{SPM.xX.iC(cInd)})...
                                );
                        end
                    case 'combineruns'
                        for origReg = unique(cellfun(@(s) regexp(s,'(?<=[0-9]\) ).*','match'), SPM.xX.name(SPM.xX,iC)),'stable')
                            contrasts(end+1)= struct(...
                                'format','uniquebyrun',...
                                'vector',contains(SPM.xX.name,origReg{1}),...
                                'session',[],...
                                'type','T',...
                                'name',sprintf('%s-o-baseline',SPM.xX.name{SPM.xX.iC(cInd)})...
                                );
                        end
                end
            end

            if isempty(contrasts), logging.error('Can''t find declaration of what contrasts to use'); end

            %% Generate contrasts
            SPM.xCon =[];
            for cInd = 1:numel(contrasts)
                % Support eval'ed strings to define contrasts (e.g. ones, eye)
                if ischar(contrasts(cInd).vector) &&...
                        ~startsWith(contrasts(cInd).vector,{'+' '-'}) % not defined with event names
                    contrasts(cInd).vector = str2num(contrasts(cInd).vector);
                end

                % Compile contrast vector
                switch contrasts(cInd).format
                    case {'*','runs'}
                        runCon = zeros(1,nRuns);
                        if strcmp(contrasts(cInd).format,'*')
                            runCon(selectedRuns) = 1;
                        else
                            [~,indRun] = intersect(runNames,contrasts(cInd).fmrirun.names);
                            if numel(indRun) ~= numel(contrasts(cInd).fmrirun.names), logging.error('Run names in the contrast specification do not match with those of the workflow'); end
                            runCon(indRun) = [contrasts(cInd).fmrirun.weights];
                        end

                        convec=[];
                        for indRunInSPM = 1:numel(selectedRuns)
                            indRun = selectedRuns(indRunInSPM);
                            nRegInRun = numel(SPM.Sess(indRunInSPM).col);
                            if runCon(indRun)
                                if isnumeric(contrasts(cInd).vector) % contrast vector
                                    if size(contrasts(cInd).vector,2) > nRegInRun
                                        logging.error('Number of columns in contrast for run %d is more than number of regressors in the model for this run (%d)',indRun,nRegInRun);
                                    elseif size(contrasts(cInd).vector,2) < nRegInRun % padding if shorter
                                        convec = [convec runCon(indRun)*contrasts(cInd).vector zeros(size(contrasts(cInd).vector,1),nRegInRun-size(contrasts(cInd).vector,2))];
                                    else
                                        convec = [convec runCon(indRun)*contrasts(cInd).vector];
                                    end
                                elseif ischar(contrasts(cInd).vector) || iscell(contrasts(cInd).vector) % (cell)string
                                    regInRun = SPM.xX.name(contains(SPM.xX.name, sprintf('Sn(%d)',indRunInSPM)));
                                    if numel(regInRun) ~= nRegInRun, logging.error('Mismatch between regressors and number of columns in run %d', indRun); end % this should never been triggered
                                    convec = [convec contrastSpecificationToContrastVector(regInRun,contrasts(cInd).vector,runCon(indRun))];
                                else
                                    logging.error('Contrast MUST be either string or numeric.');
                                end
                            else
                                convec = [convec zeros(size(contrasts(cInd).vector,1), nRegInRun)];
                            end
                        end
                        % If subjects have different # of runs, then they will be weighted differently in 2nd level model.
                        % So, normalize the contrast by the number of runs that contribute to it
                        if getSetting(rap,'scalebynumberofruns'), convec = convec ./ nnz(runCon); end


                    case 'uniquebyrun'
                        if isnumeric(contrasts(cInd).vector)
                            nRegInModel = numel(SPM.xX.name) - nRuns;
                            if size(contrasts(cInd).vector,2) > nRegInModel
                                logging.error('Number of columns in contrast is more than number of regressors in the model (%d)',nRegInModel);
                            elseif size(contrasts(cInd).vector,2) < nRegInModel
                                convec = zeros(size(contrasts(cInd).vector,1), nRegInModel);
                                convec = convec + contrasts(cInd).vector;
                            else
                                convec = contrasts(cInd).vector;
                            end
                        elseif ischar(contrasts(cInd).vector) || iscell(contrasts(cInd).vector) % (cell)string contrast across all runs (events in contrast can be missing in some runs)
                            convec = contrastSpecificationToContrastVector(SPM.xX.name,contrasts(cInd).vector,NaN);
                        else
                            logging.error('Contrast MUST be either string or numeric.');
                        end
                    otherwise
                        logging.error('Unknown format %s specified for contrast %d',contrasts(cInd).format,cInd);
                end

                % Add final constant terms
                convec = [convec zeros(size(convec,1),nRuns)];

                % Check not empty
                if ~any(convec(:)), logging.error('Contrast %d has no non-zero values',cInd); end

                % Diagnostics
                logging.info(contrasts(cInd).name);
                for cindex = SPM.xX.iC, logging.info('\t%s: %d', SPM.xX.name{cindex}, convec(cindex)); end

                if isempty(SPM.xCon)
                    SPM.xCon = spm_FcUtil('Set', contrasts(cInd).name, contrasts(cInd).type,'c', convec', SPM.xX.xKXs);
                else
                    SPM.xCon(end+1) = spm_FcUtil('Set', contrasts(cInd).name, contrasts(cInd).type,'c', convec', SPM.xX.xKXs);
                end
            end
            SPM = spm_contrasts(SPM);

            %% Describe outputs
            putFileByStream(rap,'subject',subj,'firstlevel_spm',fullfile(anadir,'SPM.mat')); % updated SPM structure
            putFileByStream(rap,'subject',subj,'firstlevel_contrastmaps',fullfile(anadir,arrayfun(@(c) c.Vcon.fname, SPM.xCon, 'UniformOutput',false)));
            putFileByStream(rap,'subject',subj,'firstlevel_statisticalmaps',fullfile(anadir,arrayfun(@(c) c.Vspm.fname, SPM.xCon, 'UniformOutput',false)));

            %% Diagnostic summary images
            diagnostics(rap,subj);

            %% Cleanup
            cd(cwd);
    end
end

function convec = contrastSpecificationToContrastVector(regNames,conSpec,conWeigth)
    indFirstRegInRun = [find(diff([0 cellfun(@(r) sscanf(r,'Sn(%d)'), regNames)])) Inf];

    convec = zeros(size(contrasts(cInd).vector,1), numel(regNames));
    if ~iscell(conSpec), conSpec = cellstr(conSpec); end
    for indRow = 1:numel(conSpec)
        for regSpec = strsplit(conSpec{indRow},'|')
            specs = strsplit(regSpec{1},'*');

            if numel(specs) == 2, weight = str2double(specs{1});
            else, weight = 1;
            end

            regName = specs{end};
            locBFSpec = regexp(regName,'[bm][0-9]*$');
            if ~isempty(locBFSpec)
                regPttrn = regName(1:locBFSpec-1);
                switch regName(locBFSpec)
                    case 'b', regPttrn = [regPttrn '*']; % basis function (of main event)
                    case 'm', regPttrn = [regPttrn 'x']; % modulator
                end
                nMatch = str2double(regName(locBFSpec+1:end));
            else
                regPttrn = [regName '*'];
                nMatch = 1;
            end

            match = find(contains(regNames,regPttrn));
            if isempty(match), match = find(contains(regNames,regPttrn(1:end-1))); end % covariates
            if isempty(match), logging.error('Model (in run) has no reggessor matching %s', regPttrn); end

            % Identify the nMatch-th match within each run
            nMatch = cell2mat(arrayfun(@(i) max(find(match>=indFirstRegInRun(i) & match<indFirstRegInRun(i+1),nMatch)), 1:numel(indFirstRegInRun)-1,'UniformOutput',false));

            match = match(nMatch);
            if isnan(conWeigth) % scalebynumberofruns
               conWeigth = 1/numel(match);
            end
            convec(indRow,match) = conWeigth*weight;
        end
    end
end

function h = diagnostics(rap,subj)
% Based on Rik Henson's script
% This calculation of efficiency takes the 'filtered and whitened' design matrix (X) as it is in SPM.

    fnSPM = getFileByStream(rap,'subject',subj,'firstlevel_spm','streamType','output');
    load(fnSPM{1},'SPM');

    % Distribution (only of T-maps)
    if getSetting(rap,'diagnostics.histogram')
        cons = SPM.xCon; cons = cons([cons.STAT]=='T');
        for c = cons
            YT = spm_read_vols(spm_vol(fullfile(SPM.swd, c.Vspm.fname)));
            hist(YT(YT~=0), 100, "facecolor", [0 0 1], "edgecolor", "none");
            title(c.name,'Interpreter','none');
            print(gcf,'-djpeg','-r150', fullfile(getPathByDomain(rap,'subject',subj), ...
                ['diagnostic_' rap.tasklist.currenttask.name '_histogram_' strreps(c.name,{' ' ':' '>'},{'' '_' '-'}) '.jpg'])); % remove "unconventional" characters
            close(gcf);
        end
    end

    % Plot with efficiency
    X = SPM.xX.xKXs.X;
    iXX=inv(X'*X);

    [~, nameCols] = strtok(SPM.xX.name(SPM.xX.iC),' ');
    nameCols = strtok(nameCols,'*');
    nameCons = {SPM.xCon.name}';
    cons = {SPM.xCon.c};
    effic = nan(numel(cons), 1);
    columnsCon = nan(numel(cons), numel(nameCols));

    for cInd = 1:numel(cons)
        fullCon = cons{cInd}';
        selCon = fullCon(SPM.xX.iC);
        columnsCon(cInd, :) = selCon;

        % Normalize Contrast
        fullCon = fullCon / max(sum(fullCon(fullCon>0)), sum(fullCon(fullCon < 0)));
        % Calculate efficiency
        effic(cInd) = trace(fullCon*iXX*fullCon')^-1;
    end

    % Resize slice display for optimal fit
    nMARGIN = 0.1;
    NPLOTPERHEIGHT = 20; % 20 contrasts per screen height
    fig = figure;
    windowSize = get(0,'ScreenSize');
    pixMARGIN = windowSize(4)*nMARGIN;
    windowSize(4) = 2*pixMARGIN+(windowSize(4)-2*pixMARGIN)/NPLOTPERHEIGHT*numel(cons);
    set(fig,'Position', windowSize);
    nHMARGIN = pixMARGIN/windowSize(4);

    % - get Text size
    ht = text(0,0,nameCons,'FontSize',12,'FontWeight','Bold','interpreter','none');
    set(ht,'Unit','normalized');
    tSize = get(ht,'Extent'); tWidth = tSize(3);
    delete(ht);

    subplot('Position', [tWidth+nMARGIN nHMARGIN 0.6-tWidth-nMARGIN 1-2*nHMARGIN]);
    imagesc(columnsCon);
    colormap(vertcat(gradCreate([0 0 1],[1 1 1],32),gradCreate([1 1 1],[1 0 0],32)));
    caxis([-1 1] * max(abs(columnsCon(:))));
    set(gca, 'YTick', 1:numel(cons), 'YTickLabel',nameCons,...
        'Xtick', 1:length(nameCols), 'XTickLabel',nameCols,...
        'XAxisLocation','top', 'XTickLabelRotation',90);
    set(gca,'FontSize',12,'FontWeight','Bold','TickLabelInterpreter','none');

    subplot('Position', [0.6 nHMARGIN 0.4-nMARGIN 1-2*nHMARGIN]);
    set(gca, 'YTick', 1:numel(cons), 'YTickLabel','');
    set(gca,'FontSize',12,'FontWeight','Bold');
    hold on;
    cmap = colorcube(numel(cons));

    if getSetting(rap,'diagnostics.estimateefficiency')
        for cInd = 1:numel(cons)
            barh(numel(cons) - cInd + 1, log(effic(cInd)), 'FaceColor',cmap(cInd,:));
        end
        ylim([0.5 numel(cons)+0.5])
        xlabel('Efficiency')
        Xs = xlim;
        efficiencyVals = gradCreate(Xs(1),Xs(2),5);
        set(gca, 'Xtick', efficiencyVals, 'XtickLabel', sprintf('%1.1f|',exp(efficiencyVals)))
    end

    fname = fullfile(getPathByDomain(rap,'subject',subj),['diagnostic_' rap.tasklist.currenttask.name '_contrasts.jpg']);
    print(fig,'-djpeg','-r150',fname);
    close(fig);
end

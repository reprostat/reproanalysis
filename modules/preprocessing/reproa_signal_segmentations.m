function rap = reproa_signal_segmentations(rap,command,subj,run)

switch command
    case 'doit'
        SEG = {'GM' 'WM' 'CSF' 'Bone' 'Soft' 'OOH'};

        fnFmri = char(getFileByStream(rap,'fmrirun',[subj run],'fmri'));

        % Load segmentationmasks
        fnMasks = getFileByStream(rap,'subject',subj,'segmentationmasks');
        segNames = fieldnames(fnMasks);
        segMasks = cellfun(@(f) spm_read_vols(spm_vol(char(fnMasks.(f)))), segNames, 'UniformOutput',false);
        % - parse
        [~, indSeg] = ismember(SEG,segNames);
        segNames = segNames(indSeg);
        segMasks = segMasks(indSeg);
        segComp = cellfun(@(s) getSetting(rap,['numberofcomponents.' s]), segNames);

        % Process segmentations
        nVox0 = cellfun(@(m) sum(m(:)>0), segMasks);

        logging.info('Removing White Matter voxels near Grey Matter');
        segMasks{strcmp(segNames,'WM')} = rmNearVox(segMasks{strcmp(segNames,'WM')}, segMasks{strcmp(segNames,'GM')}, getSetting(rap,'margins.WMtoGM'));

        logging.info('Removing CerebroSpinal Fluid voxels near Grey Matter');
        segMasks{strcmp(segNames,'CSF')} = rmNearVox(segMasks{strcmp(segNames,'CSF')}, segMasks{strcmp(segNames,'GM')}, getSetting(rap,'margins.CSFtoGM'));

        if ismember('bone',segNames)
            logging.info('Removing CerebroSpinal Fluid voxels near bone');
            segMasks{strcmp(segNames,'CSF')} = rmNearVox(segMasks{strcmp(segNames,'CSF')}, segMasks{strcmp(segNames,'bone')}, getSetting(rap,'margins.CSFtoBone'));
        end

        if ismember('OOH',segNames)
                logging.info('Removing CerebroSpinal Fluid voxels near Out-Of-Head');
            segMasks{strcmp(segNames,'CSF')} = rmNearVox(segMasks{strcmp(segNames,'CSF')}, segMasks{strcmp(segNames,'OOH')}, getSetting(rap,'margins.CSFtoOOH'));
        end

        % - convert to logical
        segMasks = cellfun(@(m) m>0, segMasks, 'UniformOutput',false);

        % - print the number of voxels in each segmentation
        nVox = cellfun(@(m) sum(m(:)), segMasks);
        arrayfun(@(s) logging.info('%s mask comprises %d -> %d voxels',segNames{s},nVox0(s),nVox(s)),1:numel(segNames));

        % Exctract signals
        V = spm_vol(fnFmri);
        meanSegSignal = zeros(numel(V), numel(segNames));
        medianSegSignal = zeros(numel(V), numel(segNames));
        compSegSignal = cell(1,numel(segNames));
        for e = 1:numel(V)
            Y = spm_read_vols(V(e));
            % Now average the data from each compartment
            meanSegSignal(e,:) = arrayfun(@(s) mean(Y(segMasks{s})),1:numel(segNames));
            medianSegSignal(e,:) = arrayfun(@(s) median(Y(segMasks{s})),1:numel(segNames));
            for s = 1:numel(segNames)
                compSegSignal{s}(e,1:nVox(s)) = Y(segMasks{s});
            end
        end
        meanSegSignal = meanSegSignal - repmat(mean(meanSegSignal),numel(V),1);
        medianSegSignal = medianSegSignal - repmat(median(meanSegSignal),numel(V),1);
        for s = 1:numel(segNames)
            [compSegSignal{s}, score] = pca(compSegSignal{s}','Algorithm','eig','Centered',true,'NumComponents',segComp(s)); % BUG: OCTAVE's pca requires two output
        end
        clear score;

        % Save output
        localPath = getPathByDomain(rap,'fmrirun',[subj run]);
        fnSignal = {fullfile(localPath,'mean_segmentationsignal.tsv') ...
                    fullfile(localPath,'median_segmentationsignal.tsv') ...
                    fullfile(localPath,'comp_segmentationsignal.tsv')};

        fid = fopen(fnSignal{1},'w');
        fprintf(fid,'%s\n',strjoin(segNames,'\t'));
        dlmwrite(fid,meanSegSignal,'precision','%1.6f','delimiter','\t','append','on');
        fclose(fid);

        fid = fopen(fnSignal{2},'w');
        fprintf(fid,'%s\n',strjoin(segNames,'\t'));
        dlmwrite(fid,medianSegSignal,'precision','%1.6f','delimiter','\t','append','on');
        fclose(fid);

        fid = fopen(fnSignal{3},'w');
        strHeader = strjoin(arrayfun(@(s) sprintf([segNames{s} 'c%d\t'],1:segComp(s)), 1:numel(segNames),'UniformOutput',false),'');
        fprintf(fid,'%s\n',strHeader(1:end-1)); % do not print the last delimiter
        dlmwrite(fid,cell2mat(compSegSignal),'precision','%1.6f','delimiter','\t','append','on');
        fclose(fid);

        streamSpec = reshape([{'mean' 'median' 'components'}; fnSignal],1,[]);
        putFileByStream(rap,'fmrirun',[subj run],'segmentationsignal',struct(streamSpec{:}));

        % Diagnostics
        % - masks
        fnTmp = tempname;
        fnTmp = arrayfun(@(s) spm_file(fnTmp,'suffix',sprintf('_%d',s),'ext','.nii'), 1:numel(segNames), 'UniformOutput',false);
        mV = V(1);
        for s = 1:numel(segNames)
            mV.fname = fnTmp{s};
            mV.dt(1) = spm_type('uint8');
            spm_write_vol(mV,segMasks{s});
        end
        registrationCheck(rap,'fmrirun',[subj run],spm_file(V(1).fname,'number',V(1).n(1)),fnTmp{:},'mode','combined');
        cellfun(@delete, fnTmp);

        % - correlated timecourses...
        streamSignal = getFileByStream(rap,'fmrirun',[subj run],'segmentationsignal');
        for f = fieldnames(streamSignal)'
            MSig = importdata(streamSignal.(f{1}){1},'\t',1);
            h = corrTCs(MSig.data,MSig.colheaders);
            set(h,'PaperPositionMode','auto');
            print(h,'-djpeg','-r150',spm_file(streamSignal.(f{1}){1},...
                                           'prefix',['diagnostics_' rap.tasklist.currenttask.name '_'],...
                                           'ext','.jpg'));
            close(h);
        end
end
end

% This function erodes an image using another:
% The eroded image (mask2erode) is checked against another (erodingMask)
% so that any voxels in "mask2erode" at a certain radius from voxels in
% "erodingMask" are removed.
function mask2erode = rmNearVox(mask2erode, erodingMask, margin)
    if margin == 0, logging.info('skipping'); return; end

    if mod(margin,2) ~= 1, logging.error('margin (%d) MUST be odd integer',margin); end

    % Then try the blunt approach
    erodingMask = smooth3(erodingMask, 'box', [margin*2+1 margin*2+1 margin*2+1]);
    mask2erode(logical(erodingMask)) = 0;
end

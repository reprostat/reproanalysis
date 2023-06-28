% aa module - Mask images from a segmented structural
% 1) Take segmentation images
% 2) Threshold them at one of the 3 different levels (zero level, strict [e.g. 99%],
% or an exclusive [highest tissue probability wins])

function rap = reproa_mask_segmentations(rap,command,subj)

switch command
    case 'doit'

        segImg = getFileByStream(rap,'subject',subj,'segmentations');
        segNames = fieldnames(segImg);
        segImg = cellfun(@(f) segImg.(f), segNames);

        %% 1) RESLICE
        if hasStream(rap,'subject',subj,'reference')
            % Get defaults
            resFlags = spm_get_defaults('coreg.write');
            resFlags.which = 1;
            resFlags.mean  = 0;
            resFlags.mask  = 1;
            spm_reslice([getFileByStream(rap,'subject',subj,'reference'); segImg],resFlags);
            segImg = spm_file(segImg,'prefix',resFlags.prefix);
        end

        %% 2) THRESHOLD

        %% IN PROGRESS
        outFn = {};

        % Load the correct resliced file!
        V = spm_vol(segImg); V = cell2mat(V);
        Y = spm_read_vols(V);

        switch getSetting(rap,'threshold')
            case 'zero'
                %% A) Zero thresholding is easy...
                for a = 1:numel(segImg)
                    Y(:,:,:,a) = Y(:,:,:,a) > 0;

                    V(a).fname = spm_file(segImg{a},'prefix','Z_');
                    outFn = [outFn, {V(a).fname}]; % Save to stream...
                    spm_write_vol(V(a), Y(:,:,:,a));

                    logging.info('Zero-thresholded image %s sums up to %d vox', ...
                                 spm_file(V(a).fname,'basename'), sum(reshape(Y(:,:,:,a),1,[])))
                end
            case 'exclusive'
                %% C) Exclusive thresholding of masks:
                % Any particular voxel has greatest chance of being...
                maxeY = max(Y,[],4);

                for a = 1:numel(segImg)
                    % We want to check where the segmentation has the
                    % greatest values
                    Y(:,:,:,a) = (Y(:,:,:,a) == maxeY) & (Y(:,:,:,a) > 0.01);

                    V(a).fname = spm_file(segImg{a},'prefix','E_');
                    outFn = [outFn, {V(a).fname}]; % Save to stream...
                    spm_write_vol(V(a), Y(:,:,:,a));

                    logging.info('Exclusively thresholded image %s sums up to %d vox', ...
                                 spm_file(V(a).fname,'basename'), sum(reshape(Y(:,:,:,a),1,[])))
                end
            otherwise
                %% B) Specific thresholding of each mask
                thr = getSetting(rap,'threshold');
                if isnumeric(thr) && numel(thr) == 1, thr = repmat(thr,1,numel(V));
                elseif isstruct(thr) && isempty(setxor(fieldnames(thr),segNames)), thr = cellfun(@(f) thr.(f), segNames);
                else, logging.error('Threshold MUST be a single value (for each segmentation) or a struct with fields correspodning to the content of the segmentations');
                end
                if numel(thr) ~= numel(V), logging.error('Threshold for each segmentation (N=%d) MUST be provided',numel(V)); end
                for a = 1:numel(segImg)
                    maxY = max(reshape(Y(:,:,:,a),1,[]));
                    if maxY < thr(a)
                        logging.error('Max of %s (%1.3f) below threshold (%f)',...
                                      spm_file(V(a).fname,'basename'),maxY,thr(a))
                    end

                    Y(:,:,:,a) = Y(:,:,:,a) > thr(a);
                    V(a).fname = spm_file(segImg{a},'prefix','S_');
                    outFn = [outFn, {(a).fname}]; % Save to stream...
                    spm_write_vol(V(a), Y(:,:,:,a));

                    logging.info('Specifically thresholded image %s sums up to %d vox', ...
                                 spm_file(V(a).fname,'basename'), sum(reshape(Y(:,:,:,a),1,[])))
                end
        end

        %% OUTPUT
        streamSpec = reshape([segNames'; outFn],1,[]);
        putFileByStream(rap,'subject',subj,'segmentationmasks',struct(streamSpec{:}));
end

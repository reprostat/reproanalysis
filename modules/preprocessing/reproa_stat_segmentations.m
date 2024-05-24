function rap = reproa_stat_segmentations(rap, command, subj)

    switch command
        case 'report'

        case 'doit'
            seg = getFileByStream(rap, 'subject',subj, 'native_segmentations','content',{'GM' 'WM' 'CSF'});
            desc = fieldnames(seg);
            segEst = char(getFileByStream(rap, 'subject',subj, 'segmentation_estimates'));
            res = load(segEst);
            % - update res
            srcrap = setSourceTask(rap,'reproa_segment');
            for s = 1:numel(srcrap.tasklist.currenttask.inputstreams)
                res.image(s) = spm_vol(char(getFileByStream(rap, 'subject',subj, srcrap.tasklist.currenttask.inputstreams(s).name)));
            end
            save(segEst,'-struct','res',spm_get_defaults('mat.format'));

            % based on SPM
            job.matfiles = {segEst};
            job.tmax = numel(desc);
            job.mask = {fullfile(spm('Dir'),'tpm','mask_ICV.nii,1')};
            job.outf = '';
            out = spm_run_tissue_volumes('exec', job);

            % based on segnentation volumes
            for s = 1:numel(desc)
                stats(s).desc = desc{s};

                V = spm_vol(seg.(desc{s}){1});
                spacedesc = spm_imatrix(V.mat);
                voxelVol = prod(abs(spacedesc(7:9)));

                stats(s).spm_vox = out.(sprintf('vol%d',s))*1e6/voxelVol;
                stats(s).spm_mm3 = out.(sprintf('vol%d',s))*1e6;

                Y = spm_read_vols(V);
                Y = Y(~isnan(Y));
                stats(s).vol_vox = sum(Y(:));
                stats(s).vol_mm3 = stats(s).vol_vox*voxelVol;
            end
            stats(end+1).desc = 'TIV';
            stats(end).spm_vox = out.vol_sum*1e6/voxelVol;
            stats(end).spm_mm3 = out.vol_sum*1e6;
            stats(end).vol_vox = sum([stats.vol_vox]);
            stats(end).vol_mm3 = sum([stats.vol_mm3]);

            fnStat = fullfile(getPathByDomain(rap, 'subject',subj), 'segmentation_stats.mat');
            if isOctave, save('-mat-binary',fnStat,'stats');
            else, save(fnStat,'stats');
            end
            putFileByStream(rap, 'subject',subj, 'segmentation_stats', fnStat);
    end
end

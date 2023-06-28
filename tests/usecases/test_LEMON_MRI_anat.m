function test_LEMON_MRI_structural(rap)
    rap.options.parallelresources.walltime = 6;

    rap.tasksettings.reproa_fromnifti_structural.sfxformodality = 'T1w:T2w';
    rap.tasksettings.reproa_coregextended_t2.reorienttotemplate = 1;

    rap.tasksettings.reproa_segment.writenormalised.method = 'none';

    rap = renameStream(rap,'reproa_stat_segmentations_00001','input','structural','reproa_coregextended_t2_00001.structural');
    rap = renameStream(rap,'reproa_stat_segmentations_00001','input','t2','reproa_coregextended_t2_00001.t2');

    rap.tasksettings.reproa_dartelnormwrite_segmentations.fwhm = [1 1 1];

    rap.tasksettings.reproa_normalise_segmentations.normaliseby = 'each';
    rap.tasksettings.reproa_normalise_segmentations.estimatefrom = 'spm';

    rap = processBIDS(rap);

    processWorkflow(rap);

    reportWorkflow(rap);
end

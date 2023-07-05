function test_LEMON_MRI_anat(rap)
    rap.tasksettings.reproa_fromnifti_structural.sfxformodality = 'T1w:T2w';
    rap.tasksettings.reproa_coregextended_t2.reorienttotemplate = 1;

    rap.tasksettings.reproa_segment.writenormalised.method = 'none';

    rap.tasksettings.reproa_dartelnormwrite_segmentations.fwhm = [1 1 1];

    rap.tasksettings.reproa_scale_segmentations.scaleby = 'each';
    rap.tasksettings.reproa_scale_segmentations.estimatefrom = 'spm';

    rap = renameStream(rap,'reproa_smooth_00001','input','fmri','normaliseddensity_segmentations');
    rap.tasksettings.reproa_smooth.FWHM = 8;

    rap = processBIDS(rap);

    processWorkflow(rap);

    reportWorkflow(rap);
end

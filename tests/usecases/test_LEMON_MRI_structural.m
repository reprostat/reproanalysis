function test_LEMON_MRI_structural(rap)
    rap.options.parallelresources.walltime = 6;

    rap.tasksettings.reproa_coregextended_t2.reorienttotemplate = 1;

    rap.tasksettings.reproa_segment.writenormalised.method = 'none';
%    rap.tasksettings.reproa_normwrite_segmentations.fwhm = 1;

    rap = processBIDS(rap);

    processWorkflow(rap);

    reportWorkflow(rap);
end

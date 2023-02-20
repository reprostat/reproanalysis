function test_MoAEpilot_fmri(rap)
    rap.acqdetails.input.correctEVfordummies = 0;
    rap = renameStream(rap,'realign_00001','input','weighting_image','fmri_sd');
    rap.tasksettings.realign.invertweighting = 1;

    rap.tasksettings.segment.normalisation.affreg = '';

    rap.tasksettings.smooth_fmri.FWHM = 6;

    rap.tasksettings.firstlevelmodel.xBF.UNITS = 'secs';
    rap.tasksettings.firstlevelmodel.includerealignmentparameters = [1 1 0; 1 1 0];

    rap.tasksettings.firstlevelthreshold.threshold.correction = 'none';
    rap.tasksettings.firstlevelthreshold.threshold.p = 0.001;
    rap.tasksettings.firstlevelthreshold.threshold.extent = 'FWE:0.05';
    
    rap = processBIDS(rap);

    rap = addContrast(rap, 'firstlevelcontrasts', '*', '*', 1, 'L_G_R','T');

    processWorkflow(rap);

    reportWorkflow(rap);
end
function test_fmritask(rap)
    rap.acqdetails.input.correctEVfordummies = 0;
    
    rap.tasksettings.reproa_segment.normalisation.affreg = '';

    rap.tasksettings.reproa_smooth_fmri.FWHM = 6;

    rap.tasksettings.reproa_firstlevelmodel.xBF.UNITS = 'secs';
    rap.tasksettings.reproa_firstlevelmodel.includemovementparameters = [1 1 0; 1 1 0];

    rap.tasksettings.reproa_firstlevelthreshold.threshold.correction = 'none';
    rap.tasksettings.reproa_firstlevelthreshold.threshold.p = 0.001;
    rap.tasksettings.reproa_firstlevelthreshold.threshold.extent = 'FWE:0.05';

    rap = processBIDS(rap);

    rap = addContrast(rap, 'reproa_firstlevelcontrasts', '*', '*', 1, 'L_G_R','T');

    processWorkflow(rap);

    reportWorkflow(rap);
end

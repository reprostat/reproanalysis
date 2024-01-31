function test_fmriconnect(rap)
    rap.acqdetails.input.remoteworkflow(1) = struct(...
       'host','',...
       'path',fullfile(rap.acqdetails.root,'test_fmritask'),...
       'allowcache',0,...
       'maxtask',''...
       );
    rap = reproaConnect(rap,'subjects','*','runs','*');

    rap.tasksettings.reproa_firstlevelmodel.xBF.UNITS = 'secs';
    rap.tasksettings.reproa_firstlevelmodel.includemovementparameters = [1 1 0; 1 1 0];

    rap.tasksettings.reproa_firstlevelthreshold.threshold.correction = 'none';
    rap.tasksettings.reproa_firstlevelthreshold.threshold.p = 0.001;
    rap.tasksettings.reproa_firstlevelthreshold.threshold.extent = 'FWE:0.05';

    rap = addEvent(rap, 'reproa_firstlevelmodel', '*', '*', 'listening', 42:84:546, 42);

    rap = addContrast(rap, 'reproa_firstlevelcontrasts', '*', '*', 1, 'L_G_R','T');

    processWorkflow(rap);

    reportWorkflow(rap);
end

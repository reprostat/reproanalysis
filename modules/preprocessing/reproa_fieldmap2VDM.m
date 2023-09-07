function [rap,resp]=reproa_fieldmap2VDM(rap,command,subj,run)

switch command
    case 'report'
        rap = registrationReport(rap,subj,run);

    case 'doit'
        domain = rap.tasklist.currenttask.domain;

        % Remove previous vdms
        cellfun(@delete, cellstr(spm_select('FPList',fullfile(getPathByDomain(rap,domain,[subj run]),rap.directoryconventions.fieldmapsdirname),'^vdm.*nii')))

        % Fieldmaps
        FM = getFileByStream(rap,domain,[subj,run],'fieldmap');
        switch numel(fieldnames(FM))
            case 8 % (shortmag, shortphase, shortreal, shortimag, longmag, longphase, longreal, longimag) (GE)
                job.data.realimag = rmfield(FM,{'shortmag' 'shortphase' 'longmag' 'longphase'});
            case 4 % (shortreal, shortimag, longreal, longimag) (Philips)
                job.data.realimag = FM;
            case 3 % (shortmag, longmag, phasediff) (Siemens)
                job.data.presubphasemag.magnitude = [FM.shortmag FM.longmag];
                job.data.presubphasemag.phase = FM.phasediff;
            case 2 % precalcfieldmap + magnitude
                job.data.precalcfieldmap.precalcfieldmap = FM.fieldmap;
                job.data.precalcfieldmap.magfieldmap = FM.magnitude;
            case 1 % precalcfieldmap
                job.data.precalcfieldmap.precalcfieldmap = FM.fieldmap;
        end

        % Load DICOM header
        load(char(getFileByStream(rap,domain,[subj,run],'fieldmap_header')),'dcmhdr'); infoFM = dcmhdr{1};
        load(char(getFileByStream(rap,domain,[subj,run],'fmri_header')),'header'); infoFmri = header{1};


        % EPI
        job.session.epi = getFileByStream(rap,domain,[subj,run],'fmri');

        % Flags
        job.defaults.defaultsval = FieldMap('SetParams');
        job.defaults.defaultsval.et = [];
        job.defaults.defaultsval.mflags.template = cellstr(job.defaults.defaultsval.mflags.template);
        job.sessname = 'session';
        job.anat = [];

        job.defaults.defaultsval.epifm = lookFor(infoFM.SequenceName,'ep'); % works for Siemen, TODO: check for others
        job.defaults.defaultsval.blipdir = (~lookFor(infoFmri.PhaseEncodingDirection,'-'))*2-1;
        job.defaults.defaultsval.maskbrain = getSetting(rap,'maskbrain',run);
        job.matchvdm = getSetting(rap,'matchvdm',run);
        job.writeunwarped = 1; % for diagnostics

        % EPI TotalEPIReadoutTime
        if isfield(infoFmri,'TotalReadoutTime'), job.defaults.defaultsval.tert = infoFmri.TotalReadoutTime*1000;
        elseif all(isfield(infoFmri,{'NumberOfPhaseEncodingSteps' 'echospacing'})) % >= SPM12
            job.defaults.defaultsval.tert = (infoFmri.NumberOfPhaseEncodingSteps-1)*infoFmri.echospacing*1000;
        elseif all(isfield(infoFmri,{'NumberofPhaseEncodingSteps' 'echospacing'})) % <= SPM8
            job.defaults.defaultsval.tert = (infoFmri.NumberofPhaseEncodingSteps-1)*infoFmri.echospacing*1000;
        else
            logging.error('No total readout time, number of phase encoding steps and/or echospacing found in fMRI header!');
        end

        if ~isfield(job.data,'precalcfieldmap')
            if all(isfield(infoFM,{'EchoTime1' 'EchoTime2'})) % BIDS
                job.defaults.defaultsval.et = [infoFM.EchoTime1,infoFM.EchoTime2]*1000; % in ms
            elseif isfield(infoFM,'EchoTime') && (numel(infoFM.EchoTime) == 2)
                job.defaults.defaultsval.et = sort(infoFM.EchoTime,'ascend');
            else
                logging.error('No dual EchoTime found in fieldmap header!');
            end
        else
            job.defaults.defaultsval.et = [0 0];
        end

        % Run
        FieldMap_Run(job);

        % Save VDM
        putFileByStream(rap,domain,[subj run],'fieldmap',...
                        spm_select('FPList',fullfile(getPathByDomain(rap,domain,[subj run]),rap.directoryconventions.fieldmapsdirname),'^vdm.*nii'));

        % Create diagnostics
        registrationCheck(rap,domain,[subj run],...
                          spm_file(job.session.epi{1},'number',',1'),...
                          spm_file(job.session.epi{1},'prefix','u'));
        % Clean
        delete(spm_file(job.session.epi{1},'prefix','u'));

    case 'checkrequirements'
        if lookFor(rap.tasklist.main(rap.tasklist.currenttask.inputstreams(strcmp({rap.tasklist.currenttask.inputstreams.name},'fieldmap')).taskindex).name,'topup') &&...
            ~hasStream(rap,'dualpefieldmap_header')
            rap = renameStream(rap,rap.tasklist.currenttask.name,'input','fieldmap_header','dualpefieldmap_header');
        end
end

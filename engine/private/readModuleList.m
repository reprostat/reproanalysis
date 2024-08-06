function modules = readModuleList(moduleList)

% moduleList = {'reproa_fromnifti_structural';
%               'reproa_fromnifti_fmri';
%               'reproa_timeseriesqc_fmri';
%               'reproa_realign';
%               'reproa_coregextended';
%               'reproa_segment';
%               'reproa_normwrite_fmri';
%               'reproa_smooth_fmri';
%               'reproa_timeseriesqc_fmri'};
% moduleList{end+1,2} = {'_fingerfootlips' 'fingerfootlips' {'reproa_firstlevelmodel';
%                                                            'reproa_firstlevelcontrasts';
%                                                            'reproa_firstlevelthreshold'};
%                        '_linebisection' 'linebisection' {'reproa_firstlevelmodel';
%                                                          'reproa_firstlevelcontrasts';
%                                                          'reproa_firstlevelthreshold'}};

switch size(moduleList,2)
    case 1 % simple
        modules = cell2struct(moduleList,'name',2)';
    case 2 % branch
        modules = cell2struct(moduleList,{'name' 'branch'},2);

        % process branches
        switch size(modules(end).branch,2)
            case 2 % non-selective
                modules(end).branch = cell2struct(modules(end).branch,{'analysisidsuffix' 'module'},2)';
            case 3 % selective
                modules(end).branch = cell2struct(modules(end).branch,{'analysisidsuffix' 'selectedruns' 'module'},2)';
        end
        for b = 1:numel(modules(end).branch)
            modules(end).branch(b).module = readModuleList(modules(end).branch(b).module);
        end
end



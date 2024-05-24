function modules = readModuleList(moduleList)

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



classdef extensionClass < toolboxClass
    properties (Access = protected)
        hGUI = []% GUI handles (mandatory for subclasses of toolboxClass)
    end

    methods
        function this = extensionClass(extDir,extURL)
            if ~exist(extDir,'dir'), dirMake(extDir); end

            extName = regexp(extURL,'(?<=-)[a-zA-Z0-9]*$','match','once');
            extDir = fullfile(extDir,extName);

            % Check URL
            if ~isValidURL(extURL), logging.error('Extension %s does not exist at %s',extName,extURL); end

            % Install
            if ~exist(extDir,'dir')
                logging.info('Extension %s not found -> Downloading',extName);
                shell(sprintf('git clone %s %s',extURL,extDir));
            else
                logging.info('Extension %s found -> Updating',extName);
                if ispc()
                    shell(sprintf('cd %s && git pull',extDir));
                else
                    shell(sprintf('cd %s; git pull',extDir));
                end
            end

            this = this@toolboxClass(extName,extDir,true,{});
        end

        function load(this)
            addpath([...
                genpath(fullfile(this.toolPath,'engine')) pathsep...
                genpath(fullfile(this.toolPath,'modules')) pathsep...
                fullfile(this.toolPath,'parametersets') pathsep...
                genpath(fullfile(this.toolPath,'examples')) pathsep ...
                genpath(fullfile(this.toolPath,'tests')) ...
                ]);

            load@toolboxClass(this);
        end

    end
end

function resp = isValidURL(URL)
    if isOctave(), extJ = javaObject('java.net.URL',URL);
    else, extJ = java.net.URL(URL);
    end
    resp = extJ.openConnection.getResponseCode == 200;
end

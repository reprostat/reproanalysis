classdef reproaClass < toolboxClass
    properties (Access = protected)
        hGUI = []% GUI handles
    end

    properties (SetAccess = private)
        date
        manuscriptRef
        manuscriptURL
        reproaURL
        reproawiki
        % user config directory
        configdir
        % user parameter file name
        parameter_filename = 'reproa_parameters_user.json';
    end

    methods
        function this = reproaClass(varargin)
            reproafile = [mfilename('fullpath') '.m'];
            repropath = fileparts(reproafile);

            % Info (JSON)
            fid = fopen(fullfile(repropath,'.zenodo.json'),'r');
            info = jsondecode(char(fread(fid,Inf)'));
            fclose(fid);
            reproname = info.name;

            this = this@toolboxClass(reproname,repropath,false,{});

            this.version = info.version;
            this.date = info.date;

            % get GitHub commit info if exists
            if exist(fullfile(this.toolPath,'.git'),'dir')
                fid = fopen(fullfile(this.toolPath,'.git','logs','HEAD'),'r');
                while ~(feof(fid)), line = fgetl(fid); end
                fclose(fid);
                % Split the line at tab (after tab = repo
                % location info)
                dat = textscan(line,'%s','delimiter','\t'); dat = dat{1};
                % Split at spaces (second to last var = date)
                dat = textscan(dat{1}, '%s','delimiter',' '); dat = dat{1};
                this.version = [this.version ' (' dat{2} ')'];
                this.date = datestr(str2double(dat{end-1})/86400 + datenum(1970,1,1),'mmm yyyy');
            end

            this.manuscriptRef = info.manuscriptRef;
            this.manuscriptURL = info.manuscriptURL;
            this.reproaURL = info.url;
            this.reproawiki = info.wiki;

            % Greet
            if ~any(strcmp(varargin,'nogreet'))
                d = textscan(this.manuscriptRef,'%s %s %s','delimiter','.','CollectOutput',true); d = d{1};
                fprintf('Welcome to reproa version %s %s\n',this.version,this.date);
                fprintf('\tIf you publish work that has used reproa, please cite our manuscript:\n');
                fprintf('\t%s\n\t%s\n\t%s\n',d{:});
                fprintf('\tat %s\n',this.manuscriptURL);
                fprintf('\nPlease visit the Repro Analysis website (%s) for more information!\n',this.reproaURL);
                fprintf('\nYou can find\n\texample parameter sets in %s and\n\texamples in %s.\n',...
                    fullfile(this.toolPath,'reproa_parametersets'),fullfile(this.toolPath,'examples'));
                fprintf('Ready.\n');
            end

            % user config directory
            if ispc, this.configdir = fullfile([getenv('HOMEDRIVE') getenv('HOMEPATH')],'.reproa');
            else, this.configdir = fullfile(getenv('HOME'),'.reproa');
            end
            makedir(this.configdir);
            addpath(this.configdir);

            % Sub-toolboxes
##            this.addToolbox(fieldtripClass(fullfile(this.toolPath,'external','fieldtrip'),'name','fieldtrip'));

            % Load
            if ~any(strcmp(varargin,'noload'))
                this.load;
            end
        end

        function close(this,varargin)
            close@toolboxClass(this)
        end

        function load(this)
            fprintf('\nPlease wait a moment, adding %s to the path\n',this.name);
            pathToAdd = strsplit(genpath(this.toolPath),pathsep); % recursively add reproa subfolders
            pathToAdd(contains(pathToAdd,'D:\Projects\reproanalysis\.git')) = []; % exclude GitHub-related path

            % exclude toolbox mods
            tbxdirs = dir(fullfile(this.toolPath,'external','toolboxes'));
            tbxdirs = tbxdirs(cellfun(@(d) ~isempty(regexp(d,'.*_mods$', 'once')), {tbxdirs.name}));
            pathToExclude = strsplit(strjoin(cellfun(@genpath, fullfile(this.toolPath,'external','toolboxes',{tbxdirs.name}), 'UniformOutput', false),pathsep),pathsep);

            addpath(strjoin(setdiff(pathToAdd,pathToExclude),pathsep));

            load@toolboxClass(this)
        end

        function unload(this)
            rmpath(this.configdir);

            unload@toolboxClass(this)
        end

        function reload(this)
            addpath(this.configdir);

            reload@toolboxClass(this)
        end
    end
end

classdef reproaClass < toolboxClass
    properties (Access = protected)
        hGUI = []% GUI handles
    end

    properties (Hidden)
        % user config directory
        configdir
        % user parameter file name
        parameterFile = 'reproa_parameters_user.xml';
    end

    properties (SetAccess = private)
        date
        manuscriptRef
        manuscriptURL
        reproaURL
        reproawiki
    end

    methods
        function this = reproaClass(varargin)
            reproafile = [mfilename('fullpath') '.m'];
            repropath = fileparts(fileparts(reproafile));

            % Info (JSON)
            fid = fopen(fullfile(repropath,'.zenodo.json'),'r');
            info = jsondecode(char(fread(fid,Inf)'));
            fclose(fid);
            reproname = info.name;

            vars = {...
                '{"name": "reproacache", "attributes": ["global"]}'...
                '{"name": "reproaworker", "attributes": ["global"]}'...
                };

            this = this@toolboxClass(reproname,repropath,false,vars);

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

            % Load
            if ~any(strcmp(varargin,'noload'))
                this.load;
            end
        end

        function close(this,varargin)
            logging.info('Closing reproa');

            close@toolboxClass(this)
        end

        function load(this)
            fprintf('\nPlease wait a moment, adding %s to the path\n',this.name);
            addpath(fullfile(this.toolPath,'utilities'));
            pathToAdd = strsplit(genpath(this.toolPath),pathsep); % recursively add reproa subfolders
            pathToAdd(contains(pathToAdd,'D:\Projects\reproanalysis\.git')) = []; % exclude GitHub-related path

            % exclude toolbox mods
            tbxdirs = dir(fullfile(this.toolPath,'external','toolboxes'));
            tbxdirs = tbxdirs(cellfun(@(d) ~isempty(regexp(d,'.*_mods$', 'once')), {tbxdirs.name}));
            pathToExclude = strsplit(strjoin(cellfun(@genpath, fullfile(this.toolPath,'external','toolboxes',{tbxdirs.name}), 'UniformOutput', false),pathsep),pathsep);

            addpath(strjoin(setdiff(pathToAdd,pathToExclude),pathsep));

            % user config directory
            if ispc, this.configdir = fullfile([getenv('HOMEDRIVE') getenv('HOMEPATH')],'.reproa');
            else, this.configdir = fullfile(getenv('HOME'),'.reproa');
            end
            dirMake(this.configdir);
            addpath(this.configdir);

            % Init globals
            global reproacache
            global reproaworker
            t = datetime(); t = t.toVec;
            reproaworker = workerClass(gethostname(),getpid,fullfile(this.configdir,'reproa.log'));
            reproacache = cacheClass();
            assignin('base','reproaworker',reproaworker);
            assignin('base','reproacache',reproacache);

            % Sub-toolboxes
            rap = readparameters(this.getUserParameterFile);
            reproaworker.logLevel = rap.options.loglevel;
            logging.info('Starting reproa');
            for tbx = reshape(rap.directoryconventions.toolbox,1,[])
                if isempty(tbx.dir), continue; end % unspecified

                if ~exist([tbx.name 'Class'],'class'), logging.error('no interface class found for toolbox %s', tbx.name); end
                constr = str2func([tbx.name 'Class']);

                params = {};
                if isfield(tbx,'extraparameters') && ~isempty(tbx.extraparameters)
                    for p = fieldnames(tbx.extraparameters)
                        val = tbx.extraparameters.(p{1});
                        if isempty(val), continue; end
                        if ischar(val) && contains(val,pathsep), val = strsplit(val,pathsep); end
                        params{end+1} = p{1};
                        params{end+1} = val;
                    end
                end
                T = constr(tbx.dir,'name',tbx.name,params{:});
                if strcmp(tbx.name,'spm'), T.setAutoLoad(); end % SPM is auto-loaded with ReproA
                this.addToolbox(T);
                reproacache(['toolbox.' tbx.name]) = T;
            end

            load@toolboxClass(this);
        end

        function unload(this,varargin)
            rmpath(this.configdir);

            unload@toolboxClass(this,varargin{:})
        end

        function reload(this,varargin)
            addpath(this.configdir);

            reload@toolboxClass(this,varargin{:})
        end

        function resp = getUserParameterFile(this,varargin)
            MAXIMUMRETRY = 1; % re-trying retrieving file

            argParse = inputParser;
            argParse.addParameter('useGUI',true,@(x) islogical(x) || isnumeric(x));
            argParse.parse(varargin{:});
            useGUI = argParse.Results.useGUI;

            resp = fullfile(this.configdir, this.parameterFile);
            if ~exist(resp,'file')
                % create paremeter file

                % Which parameter set to use as seed
                defaultdir = fullfile(this.toolPath,'parametersets');
                ui_msg = 'Select parameter set that will be used as seed';
                [seedparam, rootpath] = userinput(...
                    'uigetfile',{'*.xml','All Parameter Files' },ui_msg,defaultdir,'GUI',useGUI);
                assert(ischar(seedparam), 'Exiting, user cancelled');
                isBaseDefaults = strcmp(seedparam, 'parameters_defaults.xml');
                seedparam = fullfile(rootpath, seedparam);

                % Where to store the new parameters file
                destination = resp;

                % Get value for acq_details.root
                % Initialise the save dialogue in the current rap.acq_details.root if specified
                xml = readxml(seedparam);
                analysisroot = expandpathbyvars(xml.acqdetails.root.CONTENT);
                previous = '';
                while ~isempty(analysisroot) && ~strcmp(previous, analysisroot)
                    if exist(analysisroot, 'dir'), break; end
                    previous = analysisroot;
                    analysisroot = fileparts(analysisroot);
                end
                ui_msg = 'Location where intermediate and final analysis results will be stored';
                analysisroot = userinput('uigetdir',analysisroot,ui_msg,'GUI',useGUI);
                assert(ischar(analysisroot), 'Exiting, user cancelled');

                % Get values for other required directories.
                rawdataroot = '';
                spmroot = '';
                if isBaseDefaults
                    % Only when the base file was selected as seed. When a specific
                    % location's file was selected, assume that these values are already ok
                    % for that location.
                    ui_msg = 'Directory where raw input data can be found / will be stored';
                    rawdataroot = userinput('uigetdir',analysisroot,ui_msg,'GUI',useGUI);
                    assert(ischar(rawdataroot), 'Exiting, user cancelled');

                    ui_msg = 'Root directory of spm installation';
                    spmroot = userinput('uigetdir',analysisroot,ui_msg,'GUI',useGUI);
                    assert(ischar(spmroot), 'Exiting, user cancelled');
                end

                % Generate new parameters file
                create_minimalXML(seedparam, destination, analysisroot, rawdataroot, spmroot);
                assert(exist(destination,'file')>0,'Failed to create %s', destination);

                % Final check and messaging
                % The file should now be on the path. But check, it might not be e.g. if
                % aa was not added to the path properly before calling this function.
                % fileRetrieve(this.parameterFile,MAXIMUMRETRY); % often leads to false error

                msg = sprintf('New parameter set in %s has been created.\nYou may need to edit this file further to reflect local configuration.',destination);
                if useGUI
                    h = msgbox(msg,'New parameters file','warn');
                    waitfor(h);
                else
                    fprintf('\n%s\n',msg);
                end
            end
        end
    end
end

%% create_minimalXML
function create_minimalXML(seedparam,destination,analysisroot, rawdataroot, spmroot)

    if isOctave() % Octave
        DOMnode = javaObject ("org.apache.xerces.dom.DocumentImpl");
        root = DOMnode.createElement ('rap');
        DOMnode.appendChild (root);
    else % MATLAB
        %% Check Matlab Version
        v = ver('MATLAB');
        v = str2double(regexp(v.Version, '\d.\d','match','once'));
        if (v<7)
          error('Your MATLAB version is too old. You need version 7.0 or newer.');
        end
        DOMnode = com.mathworks.xml.XMLUtils.createDocument(RootName);
    end

    rap = DOMnode.getDocumentElement;
    rap.setAttribute('xmlns:xi','http://www.w3.org/2001/XInclude');

    seed = DOMnode.createElement('xi:include');
    seed.setAttribute('href',seedparam);
    seed.setAttribute('parse','xml');
    rap.appendChild(seed);

    local = DOMnode.createElement('local');
    rap.appendChild(local);

    if ~isempty(rawdataroot) ||  ~isempty(spmroot)
        directoryconventions = DOMnode.createElement('directoryconventions');
        local.appendChild(directoryconventions);

        if ~isempty(rawdataroot)
            rawdatadir = DOMnode.createElement('rawdatadir');
            rawdatadir.setAttribute('desc','Root on local machine for processed data');
            rawdatadir.setAttribute('ui','dir');
            rawdatadir.appendChild(DOMnode.createTextNode(rawdataroot));
            directoryconventions.appendChild(rawdatadir);
        end

        if ~isempty(spmroot)
            toolbox = DOMnode.createElement('toolbox');
            toolbox.setAttribute('desc','Toolbox with implemented interface in extrafunctions/toolboxes');
            toolbox.setAttribute('ui','custom');
            directoryconventions.appendChild(toolbox);

            spmname = DOMnode.createElement('name');
            spmname.setAttribute('desc','Name corresponding to the name of the interface without the "Class" suffix');
            spmname.setAttribute('ui','text');
            spmname.appendChild(DOMnode.createTextNode('spm'));
            toolbox.appendChild(spmname);

            spmdir = DOMnode.createElement('dir');
            spmdir.setAttribute('ui','dir_list');
            spmdir.appendChild(DOMnode.createTextNode(spmroot));
            toolbox.appendChild(spmdir);
        end
    end

    acqdetails = DOMnode.createElement('acqdetails');
    local.appendChild(acqdetails);

    root = DOMnode.createElement('root');
    root.setAttribute('desc','Root on local machine for processed data');
    root.setAttribute('ui','dir');
    root.appendChild(DOMnode.createTextNode(analysisroot));
    acqdetails.appendChild(root);

    xmlwrite(destination,DOMnode);

end

function varargout = userinput(varargin)
% Examples:
% resp = userinput('questdlg',sprintf('Cannot find parameters file %s\nSeed new parameter file from existing default?','paramfile'), 'Parameter file', 'Yes','No (Exit)','No (Exit)','GUI',true);
% [seedparam, rootpath] = userinput('uigetfile',{'*.xml','All Parameter Files' },'Desired seed parameter',defaultdir,'GUI',true);
% [defaultparameters, rootpath] = userinput('uiputfile',{'*.xml','All Parameter Files' }, 'Location of the parameters file and analyses by default',fullfile(pwd,defaultparameters),'GUI',true);

isGUI = true;
iParam = find(strcmpi(varargin,'gui'),1);
if ~isempty(iParam)
    isGUI = varargin{iParam+1};
    varargin(iParam:iParam+1) = [];
end

switch varargin{1}
    case 'questdlg' % question, title, btn1, btn2, (btn3,) default
        if isGUI
            mac_extra_print(varargin{3})
            varargout{1} = questdlg(varargin{2:end});
        else
            btns = varargin(4:end-1);
            msgBtn = sprintf(' / %s',btns{:}); msgBtn(1:3) = '';
            respList = cellfun(@(x) lower(strtok(x)), btns, 'UniformOutput', false);
            while true
                resp = input([varargin{2} ' (' msgBtn '):' ],'s');
                resp = btns(cellfun(@(x) strcmp(resp,x) || (resp==x(1)), respList));
                if ~isempty(resp), break; end
            end

            varargout{1} = resp{1};
        end
    case  'uigetdir' % path,title
        if isGUI
            mac_extra_print(varargin{3})
            varargout{1} = uigetdir(varargin{2:end});
        else
            % TODO: implement an abort option here too?
            rootpath = input([varargin{3} ' (or leave empty for ' varargin{2} '):'],'s');
            if isempty(rootpath), rootpath = varargin{2}; end

            varargout{1} = rootpath;
        end
    case  'uigetfile' % filter,title,defname
        if isGUI
            mac_extra_print(varargin{3})
            [varargout{1}, varargout{2}] = uigetfile(varargin{2:end});
        else
            defaultdir = varargin{4};
            defaultnames = dir(fullfile(defaultdir,varargin{2}{1}));
            fprintf('%s in %s:\n', varargin{2}{2}, defaultdir);
            fprintf('%s\n',defaultnames.name);
            while true
                seedparam = input([varargin{3} ' (or leave empty to abort):'],'s');
                % filter out extension (so we are robust to whether this is provided or not)
                [rootpath,seedparam,~] = fileparts(seedparam);
                if isempty(seedparam)
                    seedparam = 0; % 0 to indicate Cancel, same as uigetfile()
                    rootpath = 0;
                    break % leave empty to abort
                elseif isempty(rootpath)
                    rootpath = defaultdir;
                end
                seedparam = [seedparam varargin{2}{1}(2:end)]; %#ok<AGROW>

                if exist(fullfile(rootpath,seedparam),'file')
                    break
                else
                    fprintf('Could not find file %s in %s. Please try again!\n',seedparam, rootpath);
                end
            end

            varargout{1} = seedparam;
            varargout{2} = rootpath;
        end
    case  'uiputfile' % filter,title,defname
        if isGUI
            mac_extra_print(varargin{3})
            [varargout{1}, varargout{2}] = uiputfile(varargin{2:end});
        else
            % TODO: implement an abort option here too?
            [defaultdir, defaultseed]= fileparts(varargin{4});
            seedparam = input([varargin{3} ' (or leave empty for ' varargin{4} '):'],'s');
            % filter out extension (so we are robust to whether this is provided or not)
            [rootpath,seedparam] = fileparts(seedparam);
            if isempty(rootpath), rootpath = defaultdir; end
            if isempty(seedparam), seedparam = defaultseed; end

            varargout{1} = [seedparam varargin{2}{1}(2:end)];
            varargout{2} = rootpath;
        end
    otherwise
        error('Function %s is not an existing function or not implemented!',varargin{1});
end

end

function mac_extra_print(title)
% On mac, depending on os version, the custom dialog title does not always show
% Print the title to the command window before showing the dialog
if ismac()
    fprintf('\n');
    pause(0.5)
    fprintf('%s\n', title);
    pause(0.5)
end
end

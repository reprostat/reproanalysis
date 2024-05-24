% Based on Guillaume Flandin's spm_provenance.m and spm_results_nidm.m

classdef reproaProv < handle
    properties
        studyPath
        version
        environment
        workflow
		isValid = false

        doNotCheckInput = false
    end

    properties (Hidden, SetAccess = private)
        provlib
        rap

        relations = {}

        % so far only one subject and run are supported
        indices = [1 1 1]
    end

    properties (SetAccess = private)
        IDs = {}
        isHumanReadable = true;
    end

    methods
        function this = reproaProv(rap)
            this.rap = rap;
            this.studyPath = fullfile(this.rap.acqdetails.root,this.rap.directoryconventions.analysisid);
            this.provlib = which('spm_provenance'); % check availability
            if ~isempty(this.provlib)
				this.isValid = true;

                % Initialise
                this.environment = feval(spm_file(this.provlib,'basename'));
                this.environment.add_namespace('nfo','http://www.semanticdesktop.org/ontologies/2007/03/22/nfo');
                this.environment.add_namespace('nidm','http://purl.org/nidash/nidm#');
                this.environment.add_namespace('spm','http://purl.org/nidash/spm#');
                this.environment.add_namespace('reproa','https://raw.githubusercontent.com/reprostat/reprovenance/master/ontologies/reproa#');

                % agents
                % Parallel Computing
                this.environment.agent('idPCP1',{...
                    'prov:type','reproa:ParallelComputingProvider',...
                    'prov:label',this.rap.options.wheretoprocess,...
                    });

                % MATLAB
                this.environment.agent('idMATLAB1',{...
                    'prov:type','prov:SoftwareAgent',...
                    'prov:label',{'MATLAB','xsd:string'},...
                    'reproa:version',{this.rap.internal.matlabversion,'xsd:string'},...
                    'nfo:belongsToContainer',{this.rap.internal.matlabpath, 'nfo:Folder'},...
                    'reproa:hasSoftwareAgent','idreproa1',...
                    });

                % tools
                global reproacache
                for t = this.rap.directoryconventions.toolbox
                    if reproacache.isKey(['toolbox.' t.name])
                        tbx = reproacache(['toolbox.' t.name]);
                        tbxID = ['id' upper(tbx.name) '1'];
                        this.environment.agent(tbxID,{...
                            'prov:type','prov:SoftwareAgent',...
                            'prov:label',{upper(tbx.name),'xsd:string'},...
                            'reproa:version',{tbx.version,'xsd:string'},...
                            'nfo:belongsToContainer',{tbx.toolPath, 'nfo:Folder'},...
                            });
                        tools = {'reproa:hasSoftwareAgent',tbxID};
                    else
                        logging.warning('Toolbox %s not found',t.name);
                    end
                end

                % FSL
                if isfield(this.rap.directoryconventions,'fsldir'),
                    fsldir = this.rap.directoryconventions.fsldir;
                    fslversionfile = fullfile(fsldir,'etc','fslversion');
                    if ~isempty(fsldir) && exist(fslversionfile,'file')
                        fslversion = textread(fslversionfile,'%s');
                        this.environment.agent('idFSL1',{...
                            'prov:type','prov:SoftwareAgent',...
                            'prov:label',{'FSL','xsd:string'},...
                            'reproa:version',{fslversion{1},'xsd:string'},...
                            'nfo:belongsToContainer',{fsldir, 'nfo:Folder'},...
                            });
                        tools = [tools {'reproa:hasSoftwareAgent','idFSL1'}];
                    end
                end

                % FreeSurfer
                if isfield(this.rap.directoryconventions,'freesurferdir')
                    fsdir = this.rap.directoryconventions.freesurferdir;
                    if ~isempty(fsdir) && exist(fsdir,'dir')
                        fsversion = importdata(fullfile(fsdir,'build-stamp.txt')); fsversion = strsplit(fsversion{1},'-');
                        this.environment.agent('idFreeSurfer1',{...
                            'prov:type','prov:SoftwareAgent',...
                            'prov:label',{'FreeSurfer','xsd:string'},...
                            'reproa:version',{fsversion{end},'xsd:string'},...
                            'nfo:belongsToContainer',{fsdir, 'nfo:Folder'},...
                            });
                        tools = [tools {'reproa:hasSoftwareAgent','idFreeSurfer1'}];
                    end
                end

                % reproa
                this.environment.agent('idreproa1',[{...
                    'prov:type','reproa:Pipeline',...
                    'prov:label','Reproducibility Analysis',...
                    'nfo:belongsToContainer',{this.rap.internal.reproapath, 'nfo:Folder'},...
                    'reproa:version',{this.rap.internal.reproaversion,'xsd:string'},...
                    'reproa:isTrackKeeping','1',...
                    'reproa:hasParallelComputing','idPCP1'} ...
                    tools]...
                    );

                this.IDs{1} = struct('id','idreproaWorkflow');
                idResults = this.IDs{1}.id;
                this.environment.entity(idResults,{...
                    'prov:type','prov:Bundle',...
                    'prov:label','reproa Workflow',...
                    'reproa:objectModel','reproa:reproaWorkflow',...
                    'reproa:version',{this.version,'xsd:string'},...
                    });
                this.environment.wasGeneratedBy(idResults,'-',now);
                this.environment.wasAssociatedWith(idResults,'idreproa1');

                this.workflow = feval(spm_file(this.provlib,'basename'));
            end

        end

        function serialise(this,varargin)
            argParse = inputParser;
            argParse.addOptional('serPath',this.studyPath,@ischar)
            argParse.addOptional('serAs','pdf',@(x) (iscell(x) || ischar(x)) && ismember(x,{'provn' 'ttl' 'json' 'pdf'}))
            argParse.parse(varargin{:});

            if this.isValid
                this.environment.bundle(this.IDs{1}.id,this.workflow);

                for ser = cellstr(argParse.Results.serAs)
                    switch ser{1}
                        case 'pdf'
                            if ~system('which dot')
                                try
                                    serialize(this.environment,fullfile(argParse.Results.serPath,'rap_prov.pdf'));
                                catch E
                                    warning(E.message);
                                end
                            else
                                logging.warning('Serialising provenance as PDF requires Graphviz added to the system path.');
                            end
                        otherwise
                            serialize(this.environment,fullfile(argParse.Results.serPath,['rap_prov.' ser{1}]));
                    end
                end
            end
        end

        function idInd = addTask(this,varargin)
            % Activity
            switch numel(varargin)
                case 2 % remote
                    [host currrap] = deal(varargin{:});
                    modName = regexp(currrap.tasklist.currenttask.name,'.*(?=_0)','match','once');
                    index = str2double(regexp(currrap.tasklist.currenttask.name,'(?<=_)[0-9]{5}','match','once'));

                    name =  ['Remote ' host '_' regexp(currrap.tasklist.currenttask.name,'.*(?=_0)','match','once')];
                    idName = ['idRemoteActivity_' modName];
                    idAttr = {...
                        'rap',currrap,...
                        'Location',[host getPathByDomain(currrap,'study',[])],...
                        };

                    checkInput = false; % do not check input

                case 1 % local
                    taskInd = varargin{1};
                    currTask = this.rap.tasklist.main(taskInd);
                    name = currTask.name;
                    index = currTask.index;

                    idName = ['idActivity_' name];
                    if ~isempty(currTask.extraparameters), sfx = currTask.extraparameters.rap.directoryconventions.analysisidsuffix;
                    else, sfx = '';
                    end

                    currrap = setCurrentTask(this.rap,'task',taskInd,'subject',this.indices(1));

                    idAttr = {...
                        'rap',currrap,...
                        'Location',fullfile([this.studyPath sfx],sprintf('%s_%05d',name,index)),...
                        };

                    checkInput = true;
            end
            idAttr = [idAttr,...
                'TaskName',name,...
                'Index',index,...
                ];
            [taskID, idInd] = this.getTaskProv(idName,idAttr);

            % Input(s)
            if ~this.doNotCheckInput && checkInput

                for inp = this.IDs{idInd}.rap.tasklist.currenttask.inputstreams
                    if iscell(inp.name), inp.name = inp.name{1}; end % renamed stream
                    istream = strsplit(inp.name,'.'); istream = istream{end};

                    if isfield(inp,'path') && ~isempty(inp.path) % remote src --> add
                        dat = load(fullfile(inp.path,'rap.mat'));
                        srcIDInd = this.addTask(inp.host,setCurrentTask(dat.rap,'task',inp.taskindex));
                    else % local --> already added
                        idAttr = {...
                            'TaskName',currrap.tasklist.main(inp.taskindex).name,...
                            'Index',currrap.tasklist.main(inp.taskindex).index,...
                            };
                        [~, ~, srcIDInd] = this.idExist(idAttr);
                    end

                    pridInput = this.addStream(srcIDInd,inp);
                    if isempty(pridInput)
                        logging.error(...
                            'Inputstream %s of module %s generated by %s not found!',istream,...
                            sprintf('%s_%05d',name,index),...
                            this.IDs{srcIDInd}.rap.tasklist.currenttask.name);
                    end
                    if ~any(strcmp(this.relations,[pridInput,taskID]))
                        this.workflow.used(taskID,pridInput);
                        this.relations{end+1} = [pridInput,taskID];
                    end
                end
            end

            % Output
            for out = this.IDs{idInd}.rap.tasklist.currenttask.outputstreams
                pridOutput = this.addStream(idInd,out);
                if ~isempty(pridOutput) &&... % optional outputs
                        ~any(strcmp(this.relations,[taskID,pridOutput]))
                    this.workflow.wasGeneratedBy(pridOutput,taskID)
                    this.relations{end+1} = [taskID,pridOutput];
                end
            end

        end

        function [prid, idInd] = addStream(this,srcIDInd,stream)
            rap = this.IDs{srcIDInd}.rap;
            indices = this.indices;
            if ~isempty(rap.acqdetails.selectedruns)
                indices(2) = rap.acqdetails.selectedruns(indices(2));
            else % no selected run specified
                rap.acqdetails.selectedruns = '*';
            end

            fileList = {};
            if isfield(stream,'streamdomain') % input
                streamDomain = stream.streamdomain;
            else % output
                streamDomain = stream.domain;
            end
            indices = indices(1:size(getDependencyByDomain(rap,streamDomain),2));
            if iscell(stream.name), stream.name = stream.name{1}; end
            if ~isempty(getFileByStream(rap,streamDomain,indices,stream.name,'streamType','output','isProbe',true))
                [fileList hashList streamDescriptor] = getFileByStream(rap,streamDomain,indices,stream.name,'streamType','output');
            end
            if isempty(fileList)
                logging.warning('No outputstream %s found in task %s',stream.name,rap.tasklist.currenttask.name);
                prid = [];
                idInd = 0;
                return;
            end
            if isstruct(fileList)
                fileList = cellfun(@(f) fileList.(f), fieldnames(fileList));
                hashList = cellfun(@(f) hashList.(f), fieldnames(hashList));
            end

            % Add stream (only first file to represent)
            idName = ['id' stream.name];
            idAttr = {...
                'streamname',stream.name,...
                'filename',streamDescriptor{1},...
                'hash',hashList{1},...
                };
            [prid, idInd] = this.getStreamProv(idName,idAttr,fileList);
        end

        function [prid idInd] = getTaskProv(this,idName,idAttr) % 'Location', 'TaskName','Index'
            [prid, idNum, idInd]= this.idExist(idName,idAttr);
            if isempty(prid)
                idDef = ['id' [idName num2str(idNum+1)] idAttr];
                this.IDs{end+1} = struct(idDef{:});
                idInd = numel(this.IDs);
                prid = this.IDs{idInd}.id;

                this.workflow.activity(this.IDs{idInd}.id,{...
                    'prov:type','reproa:module',...
                    'prov:label',this.IDs{idInd}.TaskName,...
                    'nfo:belongsToContainer',{this.IDs{idInd}.Location, 'nfo:Folder'},...
                    });
            end
        end

        function [prid idInd] = getStreamProv(this,idName,idAttr,files) % 'streamname','filename(full)','hash';
            [prid, idNum, idInd]= this.idExist(idName,idAttr);
            if isempty(prid)
                idDef = ['id' [idName num2str(idNum+1)] idAttr];
                this.IDs{end+1} = struct(idDef{:});
                idInd = numel(this.IDs);
                prid = this.IDs{idInd}.id;

                % add hash
                [~, hnum]= this.idExist('idHash');
                this.IDs{end+1} = struct(...
                    'id',['idHash' num2str(hnum+1)],...
                    'hash',this.IDs{idInd}.hash ...
                    );
                this.workflow.entity(this.IDs{end}.id,{...
                    'prov:type','nfo:FileHash',...
                    'nfo:hashValue',this.IDs{end}.hash,...
                    });

                this.workflow.entity(this.IDs{idInd}.id,{...
                    'prov:type','reproa:stream',...
                    'prov:label',this.IDs{idInd}.streamname,...
                    'nfo:fileUrl',url(this.IDs{idInd}.filename),...
                    'nfo:fileName',{spm_file(this.IDs{idInd}.filename,'filename'),'xsd:string'},...
                    'nfo:hasHash',this.IDs{end}.id,...
                    });

                % add file(s)
                for f = 1:numel(files)
                    this.IDs{end+1} = struct(...
                        'id',sprintf('%s_file%d',prid,f),...
                        'filename',files{f}...
                        );
                    idFile = numel(this.IDs);
                    this.workflow.entity(this.IDs{idFile}.id,{...
                        'prov:type','nfo:LocalFileDataObject',...
                        'prov:label',sprintf('%s file #%d',this.IDs{idInd}.streamname,f),...
                        'nfo:fileUrl',url(this.IDs{idFile}.filename),...
                        'nfo:fileName',{spm_file(this.IDs{idFile}.filename,'filename'),'xsd:string'},...
                        });
                    this.workflow.hadMember(this.IDs{idInd}.id,this.IDs{idFile}.id);
                end
            end
        end

        function [prid, idNum, idInd] = idExist(this,varargin)
            prid = '';
            idNum = 0;
            idInd = 0;

            idName = '';
            idAttr = [];
            switch nargin
                case 3
                    idName = varargin{1};
                    idAttr = varargin{2};
                case 2
                    if ischar(varargin{1}), idName = varargin{1};
                    elseif iscell(varargin{1}), idAttr = varargin{1};
                    end
            end

            ind = [];
            if ~isempty(idName)
                ind = find(lookFor(cellfun(@(id) id.id, this.IDs, 'UniformOutput',false),idName));
                idNum = numel(ind);
            else
                ind = 1:numel(this.IDs);
            end

            for i = ind
                match = true;
                for f = 1:numel(idAttr)/2
                    match = match && (isfield(this.IDs{i},idAttr{f*2-1}) && ...
                        (...
                        (strcmp(idAttr{f*2-1},'rap')) ||... % skip rap
                        isequal(this.IDs{i}.(idAttr{f*2-1}), idAttr{f*2}) ...
                        ));
                end
                if match
                    prid = this.IDs{i}.id;
                    idInd = i;
                    break;
                end
            end
        end
    end
end

%% Utils

function u = url(fname)
%-File URL scheme
if ispc, s='/'; else s=''; end
u = ['file://' s strrep(fname,'\','/')];
e = ' ';
for i=1:numel(e)
    u = strrep(u,e(i),['%' dec2hex(int8(e(i)))]);
end
% u = ['file://./' spm_file(u,'filename')];
end

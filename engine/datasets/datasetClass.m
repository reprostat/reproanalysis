classdef datasetClass
    properties
        ID
        URL
        type
        subset = {}
    end

    properties (Access=private)
        tmpdir = tempname
    end

    methods
        function this = datasetClass(ID,URL,type)
            if nargin
                this.ID = ID;
                this.URL = URL;
                this.type = type;
            end
        end

        function this = set.subset(this,value)
            if ~iscell(value), value = strsplit(value,':'); end
            this.subset = value;
        end

        function download(this,demodir)
            % Download and unpack the data to a temp dir first
            if ~strcmp(this.type,'AWS')
                tgz_filename = [tempname this.type];
                options = weboptions; options.CertificateFilename = ('');
                tgz_filename = websave(tgz_filename, this.URL, options);
            end
            switch this.type
                case {'.zip'}
                    unzip(tgz_filename, this.tmpdir);
                case {'.tar.gz', '.tar'}
                    untar(tgz_filename, this.tmpdir);
                case {'AWS'}
                    if shell('which aws','quiet','ignoreerror')
                        logging.error('AWS CLI is not installed. See <a href="https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html">AWS CLI Installation</a>' );
                    end
                    % Retrieve common files (if exist)
                    shell(sprintf('aws s3 cp %s %s/%s --quiet --recursive --exclude "*" --include "task-*" --no-sign-request',this.URL,this.tmpdir,this.ID));
                    shell(sprintf('aws s3 cp %s %s/%s --quiet --recursive --exclude "*" --include "dwi*" --no-sign-request',this.URL,this.tmpdir,this.ID));

                    if isempty(this.subset) % obtain the whole dataset
                        shell(sprintf('aws s3 cp %s %s/%s --quiet --recursive --no-sign-request',this.URL,this.tmpdir,this.ID));
                    else % subset
                        for p = this.subset
                            shell(sprintf('aws s3 cp %s/%s %s/%s/%s --quiet --recursive --no-sign-request',this.URL,p{1},this.tmpdir,this.ID,p{1}));
                        end
                    end
                otherwise
                    logging.error('ERROR: unknown dataset filetype used for downloaddemo dataset: %s', dataset.filetype);
            end
            if ~strcmp(this.type,'AWS'), delete(tgz_filename); end

            if nargin > 1, this.postprocessing(demodir); end
        end

        function postprocessing(this,demodir)
            movefile(fullfile(this.tmpdir, this.ID, '*'), demodir);
        end

    end

    methods (Static = true)
        function this = empty()
            this = datasetClass();
            this = this(false);
        end
    end

end

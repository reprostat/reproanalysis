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
            this.ID = ID;
            this.URL = URL;
            this.type = type;
        end

        function this = set.subset(this,value)
            if ~iscell(value), value = strsplit(value,':'); end
            this.subset = value;
        end

        function download(this,demodir)
            % Download and unpack the data to a temp dir first
            if ~startsWith(this.type,'AWS')
                tgz_filename = [tempname this.type];
                options = weboptions; options.CertificateFilename = ('');
                tgz_filename = webSave(tgz_filename, this.URL, options);
            else
                this.type = strsplit(this.type,':');
                switch numel(this.type)
                    case 2, [this.type region] = deal(this.type{:});
                    case 1, logging.error('AWS-type dataset requires region specified as "AWS:<region>"');
                    otherwise, logging.error('Unrecognised type - "AWS:<region>" expected');
                end
            end
            switch this.type
                case {'.zip'}
                    unzip(tgz_filename, this.tmpdir);
                case {'.tar.gz', '.tar'}
                    untar(tgz_filename, this.tmpdir);
                case {'AWS'}
                    if shell('which aws','quiet',true,'ignoreerror',true)
                        logging.error('AWS CLI is not installed. See <a href="https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html">AWS CLI Installation</a>' );
                    end
                    dirMake(fullfile(this.tmpdir,this.ID));

                    % Retrieve common files
                    urlParts = strsplit(this.URL,'/');
                    bucket = urlParts{2};
                    prefix = strjoin(urlParts(3:end),'/');
                    [~,w] = shell(sprintf('aws s3api list-objects --bucket %s --prefix %s --region %s --no-sign-request',bucket,prefix,region),'quiet',1); resp = jsondecode(w);
                    files = {resp.Contents(cellfun(@(k) sum(k=='/')==1, {resp.Contents.Key})).Key};
                    for f = files
                        shell(sprintf('aws s3api get-object --bucket %s --key %s --region %s --no-sign-request %s/%s/%s',bucket,f{1},region,this.tmpdir,this.ID,spm_file(f{1},'filename')),'quiet',1);
                    end

                    % Retrieve dataset
                    if isempty(this.subset) % obtain the whole dataset
                        shell(sprintf('aws s3 cp %s %s/%s --quiet --recursive --region %s --no-sign-request',this.URL,this.tmpdir,this.ID,region));
                    else % subset
                        for p = this.subset
                            shell(sprintf('aws s3 cp %s/%s %s/%s/%s --quiet --recursive --region %s --no-sign-request',this.URL,p{1},this.tmpdir,this.ID,p{1},region));
                        end
                    end
                otherwise
                    logging.error('unknown dataset filetype used for downloaddemo dataset: %s', dataset.filetype);
            end
            if ~strcmp(this.type,'AWS'), delete(tgz_filename); end

            if nargin > 1, this.postprocessing(demodir); end
        end

        function postprocessing(this,demodir)
            movefile(fullfile(this.tmpdir, this.ID, '*'), demodir);
        end

    end

end

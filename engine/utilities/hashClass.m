classdef hashClass < handle
    properties
        hashFunc = 'MD5' % MD5 SHA-1 SHA-256
        buffSize = 1024*1024; % 1MB
        maximumRetry = 5;
    end

    properties (Access=private)
        isOctave
        md
    end

    methods
        function this = hashClass()
            this.isOctave = exist('OCTAVE_VERSION','builtin');

            if this.isOctave % OCTAVE
                this.md = javaMethod('getInstance', 'java.security.MessageDigest', this.hashFunc);
            else % MATLAB
                this.md = java.security.MessageDigest.getInstance(this.hashFunc);
            end
        end

        function update(this,data,forceString)
            if (nargin < 3 || ~forceString) && ischar(data) && exist(data,'file')
                for r = 1:this.maximumRetry
                    fid = fopen(data);
                    if fid ~= -1, break;
                    else, pause(1);
                    end
                end
                if fid == -1, logging.error('Could not find or read %s', data); end
                while ~feof(fid)
                    [currData,len] = fread(fid, this.buffSize, '*uint8');
                    if ~isempty(currData)
                        this.md.update(currData, 0, len);
                    end
                end
                fclose(fid);
            else
                this.md.update(typecast(uint16(data),'uint8'));
            end
        end

        function resp = getHash(this)
            resp = lower(reshape(dec2hex(typecast(this.md.digest(),'uint8'))',1,[]));
        end
    end

end

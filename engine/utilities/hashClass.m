classdef hashClass < handle
    properties
        hashFunc = 'MD5'
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

        function update(this,data)
            if ischar(data) && exist(data,'file')
                this.md.update(uint8(fileread(data)));
            else
                this.md.update(uint8(data));
            end
        end

        function resp = getHash(this)
            if this.isOctave % OCTAVE
                o = javaObject('java.math.BigInteger',1,this.md.digest);
            else % MATLAB
                o = java.math.BigInteger(1,this.md.digest);
            end
            resp = o.toString(16);
        end
    end

end

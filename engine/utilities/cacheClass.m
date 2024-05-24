classdef cacheClass < containers.Map
    properties
        hashFunc
    end

    properties (Access=private, Constant=true)
        validHashFuncs = 'MD5,SHA1,SHA256,SHA512'
    end

    methods
        function this = cacheClass(inp)
            this = this@containers.Map();

            if ~nargin, inp='MD5'; end

            if ischar(inp)
                assert(any(strcmp(strsplit(this.validHashFuncs,','),inp)),'wrong hash function: %s\nvalid options are: %s', inp, this.validHashFuncs);
                this.hashFunc = inp;
            else % load from struct
                this.hashFunc = inp.hashFunc;
                idx.type = '()';
                for m = inp.map
                    if isstruct(m.data) && isfield(m.data,'className')
                        constr = str2func(m.data.className);
                        m.data = constr(m.data);
                    end
                    idx.subs{1} = m.call;
                    this = this.subsasgn(idx, m.data);
                end
            end
        end

        function val = struct(this)
            val.className = 'cacheClass';
            val.hashFunc = this.hashFunc;
            val.map = cell2mat(this.values());
            for i = 1:numel(val.map)
                if isobject(val.map(i).data)
                    val.map(i).data = struct(val.map(i).data);
                end
            end
        end

        function this = subsasgn(this,idx,value)
            switch idx(1).type
                case '()'
                    v.call = idx.subs{1};
                    v.data = value;
                    value = v;
                    idx.subs{1} = doHash(this.hashFunc,idx.subs{1});
                case '.' % access custom properties
                    switch idx.subs
                        case 'hashFunc'
                            warning('Changing the hash function resets the cache!')
                            this = cacheClass(value);
                            return
                    end
            end
            this = subsasgn@containers.Map(this,idx,value);
        end

        function resp = subsref(this,idx)
            switch idx(1).type
                case '()'
                    if ~this.isKey(idx.subs{1}), error('cache has no item ''%s''',idx.subs{1}); end
                    idx.subs{1} = doHash(this.hashFunc,idx.subs{1});
                    resp = subsref@containers.Map(this,idx);
                    resp = resp.data;
                otherwise
                    resp = subsref@containers.Map(this,idx);
            end
        end

        function resp = isKey(this,key)
            resp = isKey@containers.Map(this,doHash(this.hashFunc,key));
        end

        function this = remove(this,keys)
            if ~iscell(keys), keys = {keys}; end
            keys = cellfun(@(k) doHash(this.hashFunc,k), keys, 'UniformOutput',false);
            resp = remove@containers.Map(this,keys);
        end
    end
end

function resp = doHash(hashFunc,str)
    md = hashClass();
    md.hashFunc = hashFunc;
    md.update(str,true);
    resp = char(md.getHash());
end

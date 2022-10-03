classdef cacheClass < containers.Map
    properties
        hashFunc
    end

    properties (Access=private, Constant=true)
        validHashFuncs = 'MD5,SHA1,SHA256,SHA512'
    end

    methods
        function this = cacheClass(hashFunc='MD5')
            assert(any(strcmp(strsplit(this.validHashFuncs,','),hashFunc)),'wrong hash function: %s\nvalid options are: %s', hashFunc, this.validHashFuncs);
            this.hashFunc = hashFunc;

            this = this@containers.Map();
        end

        function this = subsasgn(this,idx,value)
            switch idx(1).type
                case '()'
                    idx.subs{1} = hash(this.hashFunc,idx.subs{1});
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
                    idx.subs{1} = hash(this.hashFunc,idx.subs{1});
            end
            resp = subsref@containers.Map(this,idx);
        end

        function resp = isKey(this,key)
            resp = isKey@containers.Map(this,hash(this.hashFunc,key));
        end

        function this = remove(this,keys)
            if ~iscell(keys), keys = {keys}; end
            keys = cellfun(@(k) hash(this.hashFunc,k), keys, 'UniformOutput',false);
            resp = remove@containers.Map(this,keys);
        end
    end
end

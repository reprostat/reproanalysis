classdef logging

    methods  (Static = true)
        function this = info(varargin)
            varargin{1} = ['info: ' varargin{1} '\n'];
            fprintf(varargin{:});

            global reproaworker
            if isa(reproaworker,'workerClass'), reproaworker.addLog(varargin{:}); end
        end

        function this = warning(varargin)
            warning(sprintf(varargin{:}));

            global reproaworker
            if isa(reproaworker,'workerClass')
                varargin{1} = ['warning: ' varargin{1}];
                reproaworker.addLog(varargin{:});
            end
        end

        function this = error(varargin)
            error(sprintf(varargin{:}));

            global reproaworker
            if isa(reproaworker,'workerClass')
                varargin{1} = ['error: ' varargin{1}];
                reproaworker.addLog(varargin{:});
            end
        end
    end

end

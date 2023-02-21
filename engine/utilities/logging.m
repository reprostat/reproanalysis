classdef logging

    methods  (Static = true)
        function this = info(varargin)
            varargin{1} = ['info: ' varargin{1} '\n'];

            toLog = true;
            global reproaworker
            if isa(reproaworker,'workerClass'), toLog = reproaworker.addLog(varargin{:}); end
            if toLog, fprintf(varargin{:}); end
        end

        function this = warning(varargin)
            toLog = true;
            global reproaworker
            if isa(reproaworker,'workerClass')
                varargin{1} = ['warning: ' varargin{1}];
                toLog = reproaworker.addLog(varargin{:});
            end
            if toLog, warning(sprintf(varargin{:})); end
        end

        function this = error(varargin)
            toLog = true;
            global reproaworker
            if isa(reproaworker,'workerClass')
                varargin{1} = ['error: ' varargin{1}];
                toLog = reproaworker.addLog(varargin{:});
            end
            if toLog, error(sprintf(varargin{:})); end
        end
    end

end

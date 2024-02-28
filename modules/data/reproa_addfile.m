function rap = reproa_addfile(rap,command,varargin)

switch command
    case 'doit'
        domain = rap.tasklist.currenttask.domain;
        localPath = getPathByDomain(rap,domain,cell2mat(varargin));

        %% Select data
        data = getSetting(rap,'data');
        for iInd = 1:numel(varargin)
            data = data(cellfun(@(ind) ind(iInd) == varargin{iInd},{data.indices}));
        end

        %% Process data
        allFn = {};
        for d = reshape(data,1,[])
            % Add the files to the current task directory
            localFn = {};
            for iFn = 1:numel(d.files)
                % - split filename
                nme = spm_file(d.files{iFn}, 'basename');
                allExt = {};
                allExt{end+1} = spm_file(d.files{iFn}, 'ext');
                while ~isempty(allExt{end})
                    allExt{end+1} = spm_file(nme, 'ext');
                    nme = spm_file(nme, 'basename');
                end
                ext = strjoin(fliplr(allExt),'.');

                % - check if any file with the name aleady has been added
                nExist = sum(strcmp([nme ext],allFn));
                allFn{end+1} = [nme ext];
                localFn{end+1,1} = fullfile(localPath, sprintf('%s_%01d%s',nme,nExist,ext)); % assume <10 copies

                % - copy file
                webSave(localFn{end},d.files{iFn});
                if getSetting(rap,'uncompress')
                    switch allExt{1}
                        case 'gz'
                            fn = gunzip(localFn{end},localPath);
                        case 'zip'
                            fn = spm_file(unzip(localFn{end},localPath),'path',localPath);
                        otherwise
                            logging.warning(['Archive extension ' allExt{1} ' not supported.']);
                    end
                    delete(localFn{end});
                    localFn(end) = [];
                    localFn = [localFn; fn];
                end
            end

            % Put data into stream
            putFileByStream(rap,domain,cell2mat(varargin),d.streamname,localFn);
        end

    case 'checkrequirements'
        %% Select data
        data = getSetting(rap,'data');
        for iInd = 1:numel(varargin)
            data = data(cellfun(@(ind) ind(iInd) == varargin{iInd},{data.indices}));
        end
        if isempty(data), logging.error(['No data has been specified for ' ...
            getTaskDescription(rap,cell2mat(varargin),'indices') ...
            '.\n\tPlease check your user script!']);
        end

        %% Check data
        for d = reshape(data,1,[])
            for fn = reshape(d.files,1,[])
                [~,s] = urlread(fn{1});
                if ~s, logging.error(['Data ' fn{1} ' not found.']); end
            end
        end
end















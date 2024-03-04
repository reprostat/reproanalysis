function rap = reproa_slicetiming(rap,command,subj,run)

switch command
    case 'doit'
        pfx = 'a';

        % get files in this directory
        fnImgs = char(getFileByStream(rap,'fmrirun',[subj,run],'fmri'));

        % get information from first file
        load(char(getFileByStream(rap,'fmrirun',[subj,run],'fmri_header')),'header');
        hdr = header{1};
        TR = hdr.volumeTR;

        V = spm_vol(spm_file(fnImgs,'number',1));

        % retrieve slicetiming info
        if getSetting(rap,'useheader') % from header
            if isnumeric(hdr.sliceorder) && ~isempty(hdr.slicetimes) % exact slicetiming
                % save for outputs
                sliceOrder = hdr.sliceorder;
                refSlice = rap.tasklist.currenttask.settings.refslice;

                rap.tasklist.currenttask.settings.sliceorder = hdr.slicetimes*1000; % SPM requires ms
                rap.tasklist.currenttask.settings.refslice = rap.tasklist.currenttask.settings.sliceorder(refSlice);
                sl_times = [0 TR];
            else
                if (~isfield(header, 'sliceorder') || ~isempty(hdr.sliceorder)) && isfield(hdr,'Private_0029_1020')
                    rap.tasklist.currenttask.settings.sliceorder = getSliceOrder(V, hdr);
                end
            end
        end

        % no exact slicetiming
        if ~exist('sl_times','var')
            % [<time to acquire one slice> <time between beginning of last slice and beginning of first slice of next volume>]
            slicetime = TR/V.dim(3);
            if max(rap.tasklist.currenttask.settings.sliceorder) > V.dim(3)
                logging.error('rap.tasklist.currenttask.settings.sliceorder seems to contain values higher than the number of slices!');
            end
            sl_times = [slicetime slicetime];
            % outputs
            sliceOrder = rap.tasklist.currenttask.settings.sliceorder;
            refSlice = rap.tasklist.currenttask.settings.refslice;
        end

        % do slice timing correction
        spm_slice_timing(fnImgs,...
                         rap.tasklist.currenttask.settings.sliceorder,...
                         rap.tasklist.currenttask.settings.refslice,...
                         sl_times,...
                         pfx);

        % Describe outputs
        putFileByStream(rap,'fmrirun',[subj,run],'fmri',spm_file(fnImgs,'prefix',pfx));

        fnSliceOrder = fullfile(getPathByDomain(rap,'fmrirun',[subj,run]),'sliceorder.mat');
        save(fnSliceOrder,'sliceOrder','refSlice');
        putFileByStream(rap,'fmrirun',[subj,run],'sliceorder',fnSliceOrder);

    case 'checkrequirements'
        if isempty(rap.tasklist.currenttask.settings.sliceorder) && rap.tasklist.currenttask.settings.useheader == 0
            logging.error('no slice order information is specified\nE.g., for descending sequential 32 slices add rap.tasksettings.reproa_slicetiming.sliceorder=[32:-1:1];');
        end
end
end

function sliceOrder = getSliceOrder(V, header)
str =  header.Private_0029_1020;
xstr = char(str');
n = findstr(xstr, 'sSliceArray.ucMode');
[t, r] = strtok(xstr(n:n+100), '=');
ucmode = strtok(strtok(r, '='));

switch(ucmode)
    case '0x1' % ascending
        sliceOrder = 1:1:V.dim(3);;
        msg = 'ascending';
    case '0x2' % descending
        sliceOrder = V.dim(3):-1:1;
        msg = 'descending';
    case '0x4' % interleaved
        % Interleaved order depends on whether slice number is odd or even!
        if mod(V.dim(3),2), sliceOrder = [1:2:V.dim(3) 2:2:V.dim(3)];
        else, sliceOrder = [2:2:V.dim(3) 1:2:V.dim(3)];
        end
        msg = 'interleaved';
    otherwise
        if isfield(header, 'Private_0019_1029')
            sliceOrder = sort(header.Private_0019_1029);
            msg = 'custom (determined from field Private_0019_1029)';
        else
            logging.error('No slicetiming info found in the header!');
        end
end
end

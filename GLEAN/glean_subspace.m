function glean_subspace(GLEAN)
% Runs the subspace stage of GLEAN

method = lower(char(intersect(fieldnames(GLEAN.subspace.settings),{'pca','parcellation','voxel'})));

if ~all(cellfun(@exist,GLEAN.subspace.data))
      
    % Copy data to subspace directory
    for session = 1:numel(GLEAN.data)
        switch method
            case {'voxel','pca'}
                D = spm_eeg_load(GLEAN.envelope.data{session});
            case 'parcellation'
                D = spm_eeg_load(GLEAN.data{session});
        end
        
        D = copy(D,GLEAN.subspace.data{session});
    end
    
    % Apply normalisation
    for session = 1:numel(GLEAN.data)
        switch GLEAN.subspace.settings.normalisation
            case 'none'
                % Do nothing
            case {'voxel','global'}
                stdev = sqrt(osl_source_variance(D));
                if strcmp(GLEAN.subspace.settings.normalisation,'global')
                    stdev = mean(stdev);
                end
                M = montage(D,'getmontage');
                M.tra = diag(1./stdev)*M.tra;  
                % Remove unused montages:
                D = montage(D,'remove',1:montage(D,'getnumber'));
                D = montage(D,'add',M);
                D.save
            otherwise
                error('Invalid normalisation')
        end
        
    end
    
    
    switch method
        
        case 'voxel'
            
            % Do nothing
            
%        case 'pca'
%             
%             C = osl_groupcov(prefix({GLEAN.data.subspace},'tmp'));
%             pcadim = min(GLEAN.subspace.settings.pca.dimensionality,D.nchannels);
%             [allsvd,M] = eigdec(C,pcadim);
%             
%             if GLEAN.subspace.settings.pca.whiten
%                 M = diag(1./sqrt(allsvd)) * M';
%             else
%                 M = M';
%             end
            
            
            
        case 'parcellation'
            
            for session = 1:numel(GLEAN.data)   
                
                % Compute parcellation:
                S                   = [];
                S.D                 = GLEAN.subspace.data{session};
                S.parcellation      = GLEAN.subspace.settings.parcellation.file;
                S.mask              = GLEAN.subspace.settings.parcellation.mask;
                S.orthogonalisation = GLEAN.subspace.settings.parcellation.orthogonalisation;
                S.method            = GLEAN.subspace.settings.parcellation.method;
                glean_parcellation(S);
                
                % Compute envelopes:
                S               = [];
                S.D             = GLEAN.subspace.data{session};
                S.fsample_new   = GLEAN.envelope.settings.fsample;
                S.logtrans      = GLEAN.envelope.settings.log;
                if isfield(GLEAN.envelope.settings,'freqbands')
                    S.freqbands = GLEAN.envelope.settings.freqbands;
                else
                    S.freqbands = [];
                end
                S.demean    = 0;
                S.prefix    = '';
                D = glean_hilbenv(S);
                move(D,GLEAN.subspace.data{session})
            end
            
        otherwise
            error('I don''t know what to do!')
            
    end
%     
%     
%     % Apply spatial basis and write output files
%     for session = 1:numel(GLEAN.data)
%         
%         D = spm_eeg_load(prefix(GLEAN.data(session).subspace,'tmp'));
%         
%         montnew             = [];
%         montnew.name        = 'spatialbasis';
%         montnew.labelnew    = arrayfun(@(x) strcat(method,num2str(x)),1:size(M,1),'uniformoutput',0)';
%         montnew.labelorg    = D.chanlabels;
%         montnew.tra         = M;     
%         
%         S2 = [];
%         S2.D            = prefix(GLEAN.data(session).subspace,'tmp');
%         S2.montage      = montnew;
%         S2.keepsensors  = false;
%         S2.keepothers   = false;
%         S2.mode         = 'write';
%         
%         D = spm_eeg_montage(S2);
%         D.save;
%         
%         move(D,GLEAN.data(session).subspace)
%         unix(['rm ' strrep(prefix(GLEAN.data(session).subspace,'tmp'),'.mat','.*at')]);
%     end
%     



end
% 
% 
% 
% 
% 
%         
% 

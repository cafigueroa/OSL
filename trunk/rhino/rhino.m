function D = rhino(S)
% RHINO - Registration using Headshapes Including Nose in OSL
% performs co-registration of two sets of fiducials according 
% to sets of corresponding points and headshape points. Uses FLIRT & 
% BETSURF for scalp extraction and multistart ICP for headshape matching.
% D = rhino(S)
%
% REQUIRED INPUTS:
%
% S.D                - SPM MEG object filename
%
% S.mri              - structural MRI .nii file name OR [] or '' to use template
%
%
% OPTIONAL INPUTS 
%
% S.do_plots         - produce diagnostic plots 
%                        (default = 0)
%
% S.multistart       - number of random initialisations of headshape fitting
%                        (default 10)
%
% S.useheadshape     - used headshape points for the coregistration (0 or 1)
%                        (default = 1)
%
% S.fid_label        - Fiducial labels with fields:
%                        .nasion (Neuromag default 'Nasion')
%                        .lpa    (Neuromag default 'LPA')
%                        .rpa    (Neuromag default 'RPA')
%
% S.fid_mnicoords    - Specify fiducual MNI coordinates with fields:
%                        .nasion - [1 x 3]
%                        .lpa    - [1 x 3]
%                        .rpa    - [1 x 3]
%                        (omit field to use SPM defaults)
% 
% OR:
%
% S.fid_nativecoords - Specify native MNI coordinates with fields:
%                        .nasion - [1 x 3]
%                        .lpa    - [1 x 3]
%                        .rpa    - [1 x 3]
%                        (omit field to use MNI defaults)
%
%                            ,-.             __
%                          ,'   `---.___.---'  `.
%                        ,'   ,-                 `-._
%                      ,'    /                       \
%                   ,\/     /                        \\
%               )`._)>)     |                         \\
%               `>,'    _   \                  /       ||
%                 )      \   |   |            |        |\\
%        .   ,   /        \  |    `.          |        | ))
%        \`. \`-'          )-|      `.        |        /((
%         \ `-`   .`     _/  \ _     )`-.___.--\      /  `'
%          `._         ,'     `j`.__/           `.    \
%            / ,    ,'         \   /`             \   /
%            \__   /           _) (               _) (
%              `--'           /____\             /____\
%
% Adam Baker 2014


% Todo
% - potentially split code to separate scalp extraction & coregistration


%%%%%%%%%%%%%%%%%%%%%%%   P A R S E   I N P U T S   %%%%%%%%%%%%%%%%%%%%%%%


disp('*** RUNNING RHINO COREGISTRATION ***')


% Check SPM File Specification:
try
    S.D = char(S.D);
    [pathstr,filestr] = fileparts(S.D);
    S.D = fullfile(pathstr,[filestr '.mat']); % force .mat suffix
    D = spm_eeg_load(S.D);
catch
    error('SPM file specification not recognised or incorrect');
end

% Check Structural Specification:
try
    sMRI = char(S.mri);
    [pathstr,filestr,ext] = fileparts(sMRI);
    if isempty(ext) % force .nii suffix
        ext = '.nii';
    else
        tempMesh = spm_eeg_inv_mesh;
        sMRI     = tempMesh.sMRI;
    end
    sMRI = fullfile(pathstr,[filestr,ext]);
catch
    sMRI = ft_getopt(S,'mri','');
    error(identifier,'Structural MRI specification not recognised or incorrect');
end

% Check Headshape Specification:
try
    S = ft_checkopt(S,'useheadshape',{'single','double','logical'},{0,1});
catch
    warning('Headshape specification not recognised or incorrect, assigning default: "1"')
    S = ft_setopt(S, 'useheadshape', 1);
end%try

% Check Fiducial Label Specification:
try
    S = ft_checkopt(S,'fid_label','struct');
    assert(isfield(S.fid_label, 'nasion') &&        ...
           isfield(S.fid_label, 'lpa')    &&        ...
           isfield(S.fid_label, 'rpa'),             ...
           [mfilename ':fid_labelIncorrectFields'], ...
           'Incorrect fields in S.fid_label\n');
catch
    warning('Fiducial label specification not recognised or incorrect, assigning Elekta defaults\n')
    % default
    S = ft_setopt(S,'fid_label',struct('nasion','Nasion', ...
                                       'lpa','LPA',       ...
                                       'rpa','RPA'));
end%try
fid_labels = {S.fid_label.nasion, S.fid_label.rpa, S.fid_label.lpa};


% Check Fiducial MNI Coordinate Specification:
if isfield(S,'fid_mnicoords')
    try
        S = ft_checkopt(S,'fid_mnicoords','struct');
    catch
        error('Fiducial MNI coordinate specification should be a structure. \n');
    end%try
    fid_MNI = [S.fid_mnicoords.nasion; ...
               S.fid_mnicoords.rpa;    ...
               S.fid_mnicoords.lpa];
    % check size
    [m, n] = size(fid_MNI);
    assert(3 == m && 3 == n,[mfilename ':MNICoordsWrongDim'], ...
           'fid_mnicoords should each be a 1x3 vector. \n');
    % warning if both mni & native fiducials are specified
    if isfield(S,'fid_nativecoords')
        warning('Both MNI and native fiducials specified, using MNI fiducials')
    end   
elseif isfield(S,'fid_nativecoords')
    try
        S = ft_checkopt(S,'fid_nativecoords','struct');
    catch
        error('Fiducial native coordinate specification should be a structure. \n');
    end%try
    fid_native = [S.fid_nativecoords.nasion; ...
                  S.fid_nativecoords.rpa;    ...
                  S.fid_nativecoords.lpa];
    fid_MNI = []; % will be used later to determine coordinate space to use
    % check size
    [m, n] = size(fid_native);
    assert(3 == m && 3 == n, ...
           [mfilename ':NativeCoordsWrongDim'], ...
           'fid_nativecoords should each be a 1x3 vector. \n');     
else % default
    fid_MNI = [  1   85  -41;
                83  -20  -65;
               -83  -20  -65];
end%if

% Check Plotting Specification:
S.do_plots   = ft_getopt(S,'do_plots',   1);
S.multistart = ft_getopt(S,'multistart', 10);

useCTFhack = 0; % To be removed once my nottingham structurals have been converted correctly...
if useCTFhack==1
    warning('USING CTF HACK!!!')
end

%%%%%%%%%%%%%%%%   G E T   S C A L P   U S I N G   F S L   %%%%%%%%%%%%%%%%

[struct_path, struct_name] = fileparts(sMRI);
struct_name = strrep(struct_name,'.nii','');

% File names (generated by FSL calls)
mesh_file  = fullfile(struct_path,[struct_name '_mesh.vtk']);
trans_file = fullfile(struct_path,[struct_name '_trans.txt']);
bet_file   = fullfile(struct_path,[struct_name '_outskin_mesh.nii.gz']);
scalp_file = fullfile(struct_path,[struct_name '_scalp.nii.gz']);
std_brain  = [getenv('FSLDIR') '/data/standard/MNI152_T1_1mm.nii.gz'];


% SWITCH ORIENTATION OF SCALP FILE IF IT'S NOT THE SAME AS STD_BRAIN
% (RADIOLOGICAL)
std_orient  = call_fsl_wrapper(['fslorient -getorient ' std_brain ],1);
smri_orient = call_fsl_wrapper(['fslorient -getorient ' sMRI      ],1);
if ~strcmp(deblank(smri_orient),deblank(std_orient))
    call_fsl_wrapper(['fslorient -swaporient ' sMRI],1);
end

% RUN FSLREORIENT2STD
if ~useCTFhack
    sMRI_reorient = fullfile(struct_path,[struct_name '_reorient.nii']);    
    if exist(sMRI_reorient,'file') ~= 2
        fslreorientCommand = ['fslreorient2std ' sMRI ' ' sMRI_reorient];
        call_fsl_wrapper(fslreorientCommand, 1);
        if exist([sMRI_reorient '.gz'],'file') == 2
            gunzip([sMRI_reorient '.gz']);
            dos(['rm ' sMRI_reorient '.gz'])
        end
    end
    sMRI = sMRI_reorient;
end

% CHECK IF SCALP EXTRACTION ALREADY DONE
if exist(scalp_file,'file')~=2
    
    % RUN FLIRT
    if exist(trans_file,'file')~=2
        disp('Running FLIRT...')
        flirtCommand = ['flirt -in ' sMRI    ...
                        ' -ref ' std_brain   ...
                        ' -omat ' trans_file ...
                        ' -o ' fullfile(struct_path,[struct_name,'_MNI'])];
        call_fsl_wrapper(flirtCommand, 1);
    end
    
    % RUN BET
    if exist(mesh_file,'file')~=2
        disp('Running BET...')
        betCommand = ['bet2 ' sMRI ' ' fullfile(struct_path,struct_name) ...
                      ' -n -e'];
        call_fsl_wrapper(betCommand, 1);
    end
    
    % RUN BETSURF
    if exist(bet_file,'file')~=2
        disp('Running BETSURF...')
        betsurfCommand = ['betsurf --t1only -o ' sMRI ' ' mesh_file ...
                          ' ' trans_file                            ...
                          ' ' fullfile(struct_path,struct_name)];
        call_fsl_wrapper(betsurfCommand, 1);
    end
    
    % CLEAN UP
    warning off                                                            %#ok<WNOFF>
    dos(['rm ' fullfile(struct_path,struct_name) '*.off']);
    dos(['rm ' fullfile(struct_path,struct_name) '_outskull*.*']);
    dos(['rm ' fullfile(struct_path,struct_name) '_inskull*.*']);
    dos(['rm ' mesh_file]);
    warning on                                                             %#ok<WNON>
    
    


%%%%%%%%%%%%%%%   R E F I N E   S C A L P   O U T L I N E   %%%%%%%%%%%%%%%

disp('Running scalp extraction')

    % READ IN VOLUME & OUTLINE
    
    % check it has been created properly
    assert(logical(exist(bet_file, 'file')),    ...
           [mfilename ':BET_FILEDoesNotExist'], ...
           ['bet_file does not exist. '         ...
            'Maybe it failed to create earlier in Rhino?\n']);
       
    scalp            = read_avw(bet_file);
    [vol, ~, scales] = read_avw(sMRI);
    
    vol = vol(:,:,:,1); % In case of 4D volumes
    vol = vol ./ max(vol(:));
    
    % PLOT VOLUME AND BETSURF OUTLINE:
    if S.do_plots
        hf = figure; ha = axes('parent',hf);
        for i = 1:size(vol,3)
            im = repmat(vol(:,:,i),[1,1,3]);
            im_outline = zeros(size(im));
            im_outline(:,:,1) = scalp(:,:,i);
            im(repmat(im_outline(:,:,1),[1,1,3])==1) = 0;
            im = im + im_outline;
            image(im,'parent',ha)
            axis(ha,'image','off')
            drawnow
        end
        close(hf)
    end
    
    % CREATE MASK BY FILLING OUTLINE
    mask = ones(size(scalp)+2); % add border to account for gaps at edges
    mask(2:end-1,2:end-1,2:end-1) = scalp;
    mask([1:3,end-2:end],[1:3,end-2:end],[1:3,end-2:end]) = 0;
    mask = imfill(mask,'holes');
    mask = mask(2:end-1,2:end-1,2:end-1);
    
    % RECLASSIFY BRIGHT VOXELS OUTSIDE OF MASK (E.G. NOSE)
    vol_inside = vol;  vol_inside( mask==0) = nan;
    vol_outside = vol; vol_outside(mask==1) = nan;
    
    mix = gmdistribution(cat(1,nanmean(vol_outside(:)),nanmean(vol_inside(:))), ...
                         cat(3,nanvar(vol_outside(:)),nanvar(vol_inside(:))), ...
                         cat(1,sum(~isnan(vol_outside(:))),sum(~isnan(vol_inside(:)))));
    
    vol_outside(isnan(vol_outside)) = 0;
    idx = cluster(mix,vol_outside(:));
    mask_class = zeros(size(vol));
    mask_class(1:size(idx)) = idx;
    
    % MAKE NEW MASK FROM ORIGINAL AND RECLASSIFIED VOXELS
    mask = double(mask_class==2 | mask==1);
    
    % CLEAN UP MASK
    mask = imfill(mask,'holes');
    for i = 1:size(mask,1)
        mask(i,:,:) = bwmorph(squeeze(mask(i,:,:)),'majority');
    end
    for j = 1:size(mask,2)
        mask(:,j,:) = bwmorph(squeeze(mask(:,j,:)),'majority');
    end
    for k = 1:size(mask,3)
        mask(:,:,k) = bwmorph(squeeze(mask(:,:,k)),'majority');
    end
    mask = imfill(mask,'holes');
    
    % FILL HOLES PER SLICE (USEFUL FOR FILLING NOSTRILS)
    for i = 1:size(mask,1)
        mask(i,:,:) = imfill(squeeze(mask(i,:,:)),'holes');
    end
    for j = 1:size(mask,2)
        mask(:,j,:) = imfill(squeeze(mask(:,j,:)),'holes');
    end
    for k = 1:size(mask,3)
        mask(:,:,k) = imfill(squeeze(mask(:,:,k)),'holes');
    end
    
    % EXTRACT OUTLINE
    outline = zeros(size(mask));
    for i = 1:size(mask,1)
        outline(i,:,:) = bwmorph(squeeze(mask(i,:,:)),'remove');
    end
    for j = 1:size(mask,2)
        outline(:,j,:) = bwmorph(squeeze(mask(:,j,:)),'remove');
    end
    for k = 1:size(mask,3)
        outline(:,:,k) = bwmorph(squeeze(mask(:,:,k)),'remove');
    end
    
    % SET OUTLINE AS 1, INSIDE AS 0 AND BACKGROUND AS NAN:
    mask(mask==0)    = nan;
    mask(mask==1)    = 0;
    mask(outline==1) = 1;
    outline = mask;
    
    % SAVE AS NIFTI
    save_avw(outline,scalp_file,'d',scales);
    call_fsl_wrapper(['fslcpgeom  ' bet_file ' ' scalp_file], 1);

    % CLEAN UP
%    dos(['rm ' bet_file]);
    
    % PLOT VOLUME AND NEW OUTLINE:
    if S.do_plots
        hf = figure; ha = axes('parent',hf);
        for i = 1:size(vol,3)
            im = repmat(vol(:,:,i),[1,1,3]);
            im_outline = zeros(size(im));
            im_outline(:,:,1) = outline(:,:,i);
            im(repmat(im_outline(:,:,1),[1,1,3])==1) = 0;
            im = im + im_outline;
            image(im,'parent',ha)
            axis(ha,'image','off')
            drawnow
        end
        close(hf)
    end
    
else
    
    disp(['Loading existing scalp extraction from ' scalp_file])
    outline = read_avw(scalp_file); 
    
end



%%%%%%%%%%%%%%%   P E R F O R M   R E G I S T R A T I O N   %%%%%%%%%%%%%%%

disp('Coregistering')

% MAP INTO SCANNER COORDINATE SYSTEM
[~,qform_native] = dos(['fslorient -getqform ' sMRI]);
qform_native = str2num(qform_native);                                      
qform_native = reshape(qform_native,4,4)';

[x,y,z] = ind2sub(size(outline),find(outline == 1));
headshape = [x y z];
headshape_native = spm_eeg_inv_transform_points(qform_native,headshape);

% GET TRANSFORM FROM MNI TO NATIVE
[~,qform_mni] = dos(['fslorient -getqform ' std_brain]);
qform_mni = str2num(qform_mni);                                            
qform_mni = reshape(qform_mni,4,4)';
toMNI = load(trans_file);
% trans seems to map from native (coords) to MNI (slices) so the correct
% toMNI transformation is qform_mni*trans_file

% qform and/or sform need to be valid to keep orientation consistent:
qformcode = str2double(call_fsl_wrapper(['fslorient -getqformcode ' scalp_file], 1));
sformcode = str2double(call_fsl_wrapper(['fslorient -getsformcode ' scalp_file], 1));

if 0 == qformcode 
    warning('qform code is not valid\n');
end
if 0 == sformcode
    warning('sform code is not valid\n');
end

if 0 == qformcode && 0 == sformcode
    warning('Neither sform or qform codes are valid... we''re in trouble...\n');
    
    % I think many of my issues are coming from the fact that the qform and
    % sform matrices contain different information, and "unknown" codes. This
    % is because the CTF .nii files have been poorly converted and have unknown
    % coordinate systems. This means that the orientation is not correctly
    % accounted for by FLIRT. For now, a solution is to hack in a flip about
    % the x-axis.
    if useCTFhack
        CTFhack = [-1 0 0 0; 0 1 0 0; 0 0 1 0; 0 0 0 1];                   %#ok<UNRCH>
        toMNI   = CTFhack * qform_mni * toMNI;
    end%if
    %headshape_MNI = spm_eeg_inv_transform_points(toMNI,headshape_native);
    
else
    toMNI = qform_mni*toMNI*inv(qform_native);                            
    %headshape_MNI = spm_eeg_inv_transform_points(toMNI,headshape_native);
end

% GET POLHEMUS FIDUCIALS
fid_polhemus       = D.fiducials.fid.pnt;
polhemus_labels    = D.fiducials.fid.label;
assert(~isempty(fid_polhemus)       &&  ...
       ~isempty(polhemus_labels),       ...
       [mfilename ':NoPolhemusPoints'], ...
       'Polhemus points not found in D.fiducials. \n');

% TRANSFORM MNI FIDUCIALS TO NATIVE SPACE IF DEFINED
if ~isempty(fid_MNI)
    fid_native = [fid_MNI, ones(3,1)] * inv(toMNI)';
    fid_native = fid_native(:,1:3);
end

% MATCH FIDUCIALS
[~,fid_order] = ismember(arrayfun(@(x) {lower(polhemus_labels{x}(1:3))}, 1:length(fid_labels)),...
                         arrayfun(@(x) {lower(     fid_labels{x}(1:3))}, 1:length(fid_labels)));                     
                     
% check that all labels were written in correctly
assert(3 == length(fid_order), ...
       [mfilename ':FiducialLabelsNoMatch'], ...
       'Fiducial labels don''t match D.fiducials.fid.label. \n');
fid_labels = fid_labels(fid_order);
fid_native = fid_native(fid_order, :);


% RIGID BODY TRANSFORMATION USING FIDUCIALS
M_rigid         = spm_eeg_inv_rigidreg(fid_polhemus',   fid_native');
headshape_coreg = spm_eeg_inv_transform_points(M_rigid, headshape_native);
fid_coreg       = spm_eeg_inv_transform_points(M_rigid, fid_native);

% CREATE SURFACE MESH ON WHICH TO OVERLAY ICP FIT
mask = outline; mask(~isnan(mask)) = 1; mask(isnan(mask)) = 0;
%mask = permute(mask,[2 1 3]); % no idea why I need to permute this...
[x,y,z] = meshgrid(1:size(mask,1), 1:size(mask,2), 1:size(mask,3));
x = permute(x,[2 1 3]);
y = permute(y,[2 1 3]);
z = permute(z,[2 1 3]);

mask = smooth3(mask,'gaussian',[9,9,9]);
scalp_rhino = isosurface(x,y,z,mask);
scalp_rhino = reducepatch(scalp_rhino,0.1);
scalp_rhino.vertices = spm_eeg_inv_transform_points(qform_native,scalp_rhino.vertices);
scalp_rhino.vertices = spm_eeg_inv_transform_points(M_rigid,scalp_rhino.vertices);



% SET UP PLOT
if S.do_plots
    hf       = figure; 
    ha       = axes('parent',hf);
    patch(struct('faces',    scalp_rhino.faces,     ...
                 'vertices', scalp_rhino.vertices), ...
          'FaceColor', [238,206,179]./255,          ...
          'EdgeColor', 'none',                      ...
          'FaceAlpha', 0.5,                         ...
          'Parent', ha);
    view(90,0); 
    axis(ha,'image','off')
    material shiny
    lighting gouraud
    camlight(0,0);
    rotate3d(hf, 'on');
else
    hf = [];
    ha = [];
end%if
% neat cleanup, even if stopped by error
close_hf = onCleanup(@() close(hf));

% ICP RIGID BODY TRANSFORMATION USING HEADSHAPE POINTS AND SCALP OUTLINE
if S.useheadshape,
    % get headshape points
    headshape_polhemus = [D.fiducials.pnt; D.fiducials.fid.pnt];
    assert(~isempty(headshape_polhemus),      ...
           [mfilename ':NoHeadhshapePoints'], ...
           'Headshape points not found in D.fiducials.pnt. \n');
    % Reset random number seed (to ensure consistency over multiple sessions)
    rng(1,'twister'); 
    % Run ICP with multiple initialisations
    M_icp_inv = rhino_icp(headshape_coreg', headshape_polhemus', S.multistart, ha);
    M_icp     = inv(M_icp_inv);
    % headshape_coreg = spm_eeg_inv_transform_points(M_icp,headshape_coreg);
    fid_coreg       = spm_eeg_inv_transform_points(M_icp, fid_coreg);
else
    % just keep results from rigid body
    M_icp = eye(4);
end%if

% APPLY TO SURFACE MESH VERTICES
scalp_rhino.vertices = spm_eeg_inv_transform_points(M_icp,scalp_rhino.vertices);

if S.do_plots
    clear close_hf
end




%%%%%%%%%%%%%%%   P O P U L A T E   M E E G   F I E L D S  %%%%%%%%%%%%%%%%

if isfield(D,'inv')
    D = rmfield(D,'inv');
end

% COMPUTE MESHES
disp('Computing SPM meshes')
D.inv{1}.mesh = spm_eeg_inv_mesh(sMRI,2);

% MESHES IN MNI SPACE (so far haven't used scalp.mat - may be necessary)
Mgifti = M_icp * M_rigid * inv(toMNI) * D.inv{1}.mesh.Affine;


% APPEND RHINO MESH TO SPM OBJECT
D.inv{1}.mesh.tess_rhino.face = scalp_rhino.faces;
D.inv{1}.mesh.tess_rhino.vert = scalp_rhino.vertices;

scalp          = gifti(D.inv{1}.mesh.tess_scalp);
scalp.vertices = spm_eeg_inv_transform_points(Mgifti,scalp.vertices);
scalp          = struct('faces',scalp.faces,'vertices',scalp.vertices);
% ctx            = gifti(D.inv{1}.mesh.tess_ctx);
% ctx.vertices   = spm_eeg_inv_transform_points(Mgifti,ctx.vertices);
% ctx            = struct('faces',ctx.faces,'vertices',ctx.vertices);

D.inv{1}.comment = 'rhino';
D.inv{1}.date = char({date; datestr(now,'HH:MM')});

% WRITE DATAREG TO SPM OBJECT
D.inv{1}.datareg.sensors           = D.sensors('MEG');
D.inv{1}.datareg.fid_eeg           = D.fiducials;
D.inv{1}.datareg.fid_mri.fid.label = fid_labels;
D.inv{1}.datareg.fid_mri.fid.pnt   = fid_coreg;
D.inv{1}.datareg.fid_mri.pnt       = scalp.vertices;
D.inv{1}.datareg.fromMNI           = M_icp * M_rigid * inv(toMNI);
D.inv{1}.datareg.toMNI             = inv(D.inv{1}.datareg.fromMNI);
D.inv{1}.datareg.modality          = 'MEG';

D.save;


%%%%%%%%%%%%%%%%%%%%%%%   P L O T   R E S U L T S  %%%%%%%%%%%%%%%%%%%%%%%%
if S.do_plots
    rhino_display(D);
end
disp('***  RHINO COREGISTRATION COMPLETE ***')
end%rhino
%#ok<*ST2NM> % suppress str2num warnings
%#ok<*MINV>  % suppress inv warnings as only small affine matrices are being inverted
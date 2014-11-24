function osl_render4D(nii,savedir,workbenchdir,interptype,visualise)
% Creates a surface rendering of a 4D nifti file and saves as dense time series
% (.dtseries.nii) CIFTI file using HCP workbench
%
% OSL_RENDER4D(nii,fnameout,workbenchdir,interptype,visualise)
% -----------------------------------------------------------------
% nii          - the (3D or 4D) nifti file to render (.nii or .nii.gz)
% savedir      - a directory in which to save the surface renderings
% workbenchdir - directory containing HCP workbench (e.g. /.../workbench/bin_linux64/)
% interptype   - (optional) interpolation method [{'trilinear'},'nearestneighbour']
% visualise    - (optional) open workbench after rendering [{1},0]
% -----------------------------------------------------------------
% Adam Baker 2013

global OSLDIR;

if ~isempty(strfind(nii,'.nii.gz'))
  ext = '.nii.gz';
elseif ~isempty(strfind(nii,'.nii'))
  ext = '.nii';
else
  error('input should be nii or nii.gz file');
end

[~,infile] = fileparts(nii);

outfile = fullfile(savedir,infile);
outfile = strrep(outfile,'.gz','');
outfile = strrep(outfile,'.nii','');


if ~exist('workbenchdir','var') || isempty(workbenchdir)
 % workbenchdir = '/home/abaker/Code/HCPworkbench/bin_linux64';
  workbenchdir = '/home/abaker/Desktop/workbench/bin_linux64';
end
if ~exist('interptype','var')
  interptype = 'trilinear';
end
if ~exist('visualise','var')
  visualise = 1;
end

switch lower(interptype)
    case {'trilinear'}
        interptype_surf = 'trilinear'; 
    case {'nearestneighbour','none'}
        interptype_surf = 'enclosing'; 
    otherwise
end

if ~isdir(savedir); mkdir(savedir); end

% Load surfaces to map to
surf_right       = [OSLDIR '/std_masks/ParcellationPilot.R.midthickness.32k_fs_LR.surf.gii'];
surf_left        = [OSLDIR '/std_masks/ParcellationPilot.L.midthickness.32k_fs_LR.surf.gii'];
%surf_right  = [OSLDIR '/std_masks/ParcellationPilot.R.inflated.32k_fs_LR.surf.gii'];
%surf_left   = [OSLDIR '/std_masks/ParcellationPilot.L.inflated.32k_fs_LR.surf.gii'];
%surf_right = [OSLDIR '/std_masks/ParcellationPilot.R.very_inflated.32k_fs_LR.surf.gii'];
%surf_left  = [OSLDIR '/std_masks/ParcellationPilot.L.very_inflated.32k_fs_LR.surf.gii'];

output_right    = [outfile '_right.nii'];
output_left     = [outfile '_left.nii'];

% Map volume to surface
dos([workbenchdir '/wb_command -volume-to-surface-mapping ' nii ' ' surf_right       ' ' output_right    ' -' interptype_surf]);
dos([workbenchdir '/wb_command -volume-to-surface-mapping ' nii ' ' surf_left        ' ' output_left     ' -' interptype_surf]);

% Save as dtseries 
cifti_right = strrep(output_right,'.nii','.dtseries.nii');
cifti_left  = strrep(output_left, '.nii','.dtseries.nii');

dos([workbenchdir '/wb_command -cifti-create-dense-timeseries ' cifti_right     ' -right-metric ' output_right]);
dos([workbenchdir '/wb_command -cifti-create-dense-timeseries ' cifti_left      ' -left-metric '  output_left ]);

% View in workbench
if visualise
  runcmd([workbenchdir '/workbench ' surf_left ' ' surf_right ' ' cifti_left ' ' cifti_right ' &']);
end
end

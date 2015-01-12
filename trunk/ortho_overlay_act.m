function  ortho_overlay_act( S )
                
% ortho_overlay_act( S )
%
% S.fname is name of nii file in MNI space
% S.vol_index is vol index (counting from 1) - if not set will assume fname
% is 3D
% S.mni_coord in mm
% S.gridstep is desired spatial resolution in mm
% S.title
% S.percrange (sets S.range using percentiles) 
% or S.range (sets range directly)
% S.add_colorbar

global OSLDIR;

set(gcf,'Color','k');

act_cmapname='red2yellow';
deact_cmapname='cool';

try, tmp=S.title; catch, S.title=''; end;
try, tmp=S.add_colorbar; catch, S.add_colorbar=1; end;
try, tmp=S.gridstep; catch, S.gridstep=2; end;

fname=S.fname;
can_delete_fname=0;

% extract volume from 4d
if isfield(S,'vol_index'),
    [pth name ext]=fileparts(fname);
    new_fname=[pth '/' name '_vol' num2str(S.vol_index) '.' ext];
    runcmd(['fslroi ' fname ' ' new_fname ' ' num2str(S.vol_index-1) ' 1']);
    fname=new_fname;
    can_delete_fname=1;
else
    % assume vol is 3D
end;

% get current gridstep
[ mni_res ] = get_nii_spatial_res( fname );
mni_res=mni_res(1);

% resample volume
if mni_res~=S.gridstep,
    [pth name ext]=fileparts(fname);
    new_fname=[pth '/' name '_' num2str(S.gridstep) 'mm' '.' ext];
    
    tmp = osl_resample_nii(fname, new_fname, S.gridstep, 'sinc');
    
    if can_delete_fname,
        runcmd(['rm -f ' fname]);
    end;
    
    fname=new_fname;
    can_delete_fname=1;
    
    mni_res=S.gridstep;
end;

% find index for mni coord
ind = osl_mnicoords2ind(S.mni_coord, mni_res);
ind=ind+1;
map=ra(fname);
bgmap=ra([OSLDIR '/std_masks/MNI152_T1_' num2str(mni_res) 'mm_brain']);
map=mean(map,4); 
x1=squash(abs(map),abs(map));

if isfield(S, 'percrange'),
    try
        low=percentile((x1),S.percrange(1));
        high=percentile((x1),S.percrange(2));
    catch
        low=min(x1);
        high=max(x1);
    end;
else
    low=S.range(1);
    high=S.range(2);
end;

if(low==high)
    low=min(x1);
    high=max(x1);
end;
    
% plot colorbar
if(S.add_colorbar)   
    ind_start=2;
    num_subplots=5;
    snugplot(1,num_subplots,5);
    make_colorbar([low high],act_cmapname);
    set(gca,'YColor','w');
    freezeColors; % needed as colormaps are a property of the whole figure;

    snugplot(1,num_subplots,1);
    make_colorbar([-low -high],deact_cmapname);
    set(gca,'YColor','w');
    freezeColors; % needed as colormaps are a property of the whole figure;
else
    ind_start=1;
    num_subplots=3;    
end;

% plot ortho views
snugplot(1,num_subplots,ind_start,0.05);
overlay_act(flipud(squeeze(map(ind(1),:,:))'), flipud(squeeze(bgmap(ind(1),:,:))'),'red2yellow',0,[low high],[3000 8000],deact_cmapname,[low high]);
title([S.title],'fontsize',14);
snugplot(1,num_subplots,ind_start+1,0.05);
overlay_act(flipud(squeeze(map(:,ind(2),:))'), flipud(squeeze(bgmap(:,ind(2),:))'),'red2yellow',0,[low high],[3000 8000],deact_cmapname,[low high]);
snugplot(1,num_subplots,ind_start+2,0.05);
overlay_act(flipud(squeeze(map(:,:,ind(3)))'), flipud(squeeze(bgmap(:,:,ind(3)))'),'red2yellow',0,[low high],[3000 8000],deact_cmapname,[low high]);
   
set(gcf, 'InvertHardCopy', 'off');

end

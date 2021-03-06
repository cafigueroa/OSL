function [mni_flipped,dat_flipped] = flip_voxels(mni,dat)

    mni_flipped = mni;
    dat_flipped = dat;

    flips = [];

    for idx = 1:size(mni,1)

        target = mni(idx,:);

        % We only want to flip the RHS and nothing we have already flipped
        if sign(target(1)) == -1 || ismember(idx,flips)
            continue
        end

        target(1) = -target(1);

        [flip_idx,flip_coord] = find_nearest_coordinate(target,mni);

        % Don't flip unless we have an exact match
        if abs(flip_coord(1)) ~= abs(target(1)) || flip_coord(2) ~= target(2) || flip_coord(3) ~= target(3)
            continue
        end

        mni_flipped(idx,:) = mni(flip_idx,:);
        mni_flipped(flip_idx,:) = mni(idx,:);

        dat_flipped(idx,:) = dat(flip_idx,:);
        dat_flipped(flip_idx,:) = dat(idx,:);

        flips(end+1) = flip_idx;

    end

end






%%%-------------------------------------------------------------------------
%%% Stolen from +MEGSim in osl2



function [dipMeshInd, actualDipPos] = find_nearest_coordinate(...
                                             dipoleCoords, MNIcoords)
%FIND_NEAREST_COORDINATE finds closest points on mesh to specified locations
% [DIPMESHIND, DIPPOS] = FIND_NEAREST_COORDINATE(DIPCOORDS, MNICOORDS)
%   maps dipole co-ordinates DIPCOORDS to their closest locations on a mesh
%   of points, MNICOORDS. It returns the new, re-mapped positions DIPPOS
%   and the indices on the mesh corresponding to these positions
%   DIPMESHIND.


%       Copyright 2014 OHBA
%       This program is free software: you can redistribute it and/or modify
%       it under the terms of the GNU General Public License as published by
%       the Free Software Foundation, either version 3 of the License, or
%       (at your option) any later version.
%
%       This program is distributed in the hope that it will be useful,
%       but WITHOUT ANY WARRANTY; without even the implied warranty of
%       MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
%       GNU General Public License for more details.
%
%       You should have received a copy of the GNU General Public License
%       along with this program.  If not, see <http://www.gnu.org/licenses/>.


%       $LastChangedBy: giles.colclough@gmail.com $
%       $Revision: 213 $
%       $LastChangedDate: 2014-07-24 12:39:09 +0100 (Thu, 24 Jul 2014) $
%       Contact: giles.colclough 'at' magd.ox.ac.uk
%       Originally written on: GLNXA64 by Giles Colclough, 25-Oct-2013 12:43:45


nDipoles = size(dipoleCoords, 1);

% map to mesh
for iDipole = nDipoles:-1:1,
    meshToDipoleVectors = bsxfun(@minus, ...
                                 MNIcoords, ...
                                 dipoleCoords(iDipole, :));
    [~, dipMeshInd(iDipole)] = min(sum(meshToDipoleVectors.^2, 2));
    actualDipPos(iDipole, :) = MNIcoords(dipMeshInd(iDipole), :);
end%for
end%find_nearest_coordinate

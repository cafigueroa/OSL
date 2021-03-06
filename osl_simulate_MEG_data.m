function [Dsimulated, ...
          SimulationSpace, ...
          ReconResultsOut, ...
          beamformedOil, ...
          DebugResults,data] = osl_simulate_MEG_data(varargin)
%OSL_SIMULATE_MEG_DATA simulates MEG sensor data
%
% Simulates MEG data using an exisiting MEEG object as template. Allows
% generation of fields from sets of dipoles with differing signals. This
% provides more extensive functionality than ft_dipolesimulation. 
%
% Simulated data will inherit all properties of base object unless
% otherwise specified. This includes fiducials, sensors, channels, etc.
%
% Usage:
% DSIMULATED = OSL_SIMULATE_MEG_DATA(DIPOLEPOS, SIGNALS, TEMPLATEMEEG)
%   creates spm MEEG object DSIMULATED containing signals in MEG sensors
%   simulated from a set of dipoles at Nx3 MNI coordinates DIPOLEPOS, using
%   each row of NxS SIGNALS matrix as the activation of each dipole. 
%
%   White or structured noise can be added to the MEG sensors using 
%   parameter-value pairs (see below). 
%
%   DSIMULATED will be saved to disc in the current directory.  
%
%   SIGNALS may be specified as an nTrialsx1 cell array, each cell holding 
%   an NxS signal matrix. 
%   Each cell will provide the signal for a different trial.
%   
%   SIGNALS may also be specified as a structure, with fields 'amplitude',
%   'frequency', 'nTrials', 'phase', 'trialLength'. Identical signals will
%   be constructed from this information for each dipole. 
%   e.g.
%     SIGNALS = struct('amplitude',    1, ...
%                      'frequency',   12, ... % Hz
%                      'nTrials',      1, ...
%                      'phase',        0, ... % radians
%                      'trialLength', 30);    % s
%
%   A template MEEG object must be passed in or specified by filename in
%   TEMPLATEMEEG. The simulated object will inherit the scanner type,
%   sensor types, fiducial locations, and channels corresponding to MEG
%   data acquisition. Channels not holding simulated data will not be
%   inherited. 
%
%   You should be able to examine the data using functions such as
%   SPM_EEG_REVIEW(DSIMULATED) or OSLVIEW(DSIMULATED). For more information
%   on using spm objects, type METHODS('meeg') or HELP MEEG. 
%
% [DSIMULATED, SIMULATIONSPACE] = OSL_SIMULATE_MEG_DATA(DIPOLEPOS, SIGNALS, TEMPLATEMEEG)
%   creates structure SIMULATIONSPACE with fields
%       MNIbrainMesh          - The simulation co-ordinate space
%                               [nPointsx3]
%       simulatedMNIdipolePos - Dipole positions (mapped to closest
%                               simulation co-ordinate) [Nx3]
%       dipoleIndicesOnMesh   - Index of dipole positions in the mesh, such
%                               that MNIbrainMesh(dipoleIndicesOnMesh(i),:)
%                               is equal to simulatedMNIdipolePos(i,:)
%       MNIdipoleOrientations - The orientation of each dipole in MNI space
%                               [Nx3]
%
% [DSIMULATED, SIMULATIONSPACE, RECONRESULTSOUT] = OSL_SIMULATE_MEG_DATA(...) 
%   provides results structure RECONRESULTSOUT from source reconstruction
%   using osl. This contains the simulation grid, head model and lead
%   fields. This functionality allows for more rapid re-runs. 
%
% [...] = OSL_SIMULATE_MEG_DATA(..., 'beamformerResults', RECONRESULTSOUT)
%   uses results structure RECONRESULTSOUT from source reconstruction to
%   provide the simulation grid, head model and lead fields. This speeds up
%   repeat function runs. 
%
% [...] = OSL_SIMULATE_MEG_DATA(..., 'Parameter', 'Value') provides additional
%   options:
%    'fSample'            - sample rate in Hz [250]
%
%    'spatialResolution'  - spatial resolution of simulation grid in mm [8]
%
%    'whiteSignalToNoiseRatio' - adds white noise by specifying a 
%                           signal-to-noise power ratio in sensors [0]
%
%    'noiseLevel'         - adds white noise at specified level (specify in
%                           sensor units per root Hz). Must also specify a
%                           bandwidth [0].
%                           If both a noiseLevel and signal-to-noise ratio 
%                           are specified, both forms of noise are added. 
%
%    'noiseBandWidth'     - bandwidth for the noise (in Hz) [0]. 
%
%    'emptyRoomNoiseCovariance' - a covariance matrix for generating
%                           structured noise, for example, taken from empty
%                           room measurements. The size of the covariance
%                           matrix must match the number of meg channels to
%                           be simulated. A covariance matrix for noise
%                           measured on an Electa Neuromag system is
%                           provided in
%                           neuromag_empty_room_noise_covariance.mat []
%
%    'structuredSignalToNoiseRatio'- A signal-to-noise ratio for adding structured
%                           noise using the supplied
%                           emptyRoomNoiseCovariance matrix. [0]
%                           If either form of white noise is specified, the
%                           structure noise will be added on top. 
%
%    'structuralFile'     - structural MRI to use in forward model. An empty
%                           input uses the default MNI template. ['']
%
%    'dipoleOrientations' - allows input of the orientation of each dipole,
%                           as an Nx3 matrix. If no orientations are
%                           supplied, dippoles are simulated as being
%                           perpendicular to the cortical surface. []
%
%    'fileName'           - file name for saving DSIMULATED to disc. The
%                           directory in which this fileName is located
%                           will also be used to save any debugging plots. 
%
%    'rndSeed'            - Seed for the random number generator [random]
%
% Example:
% [Dsimulated, SimulationSpace, ReconResults, bfOil, DebugResults] = ...
%     OSL_SIMULATE_MEG_DATA([  26 -94 -8; ...   % R V1 Visual cortex
%                            -22 -94 -8]; ...  % L V1 visual cortex
%                          signals, ...
%                          fullfile(dataDir, 'ctf_fingertap_subject1_data', 'dsubject1');, ...
%                          'fSample',             250, ...
%                          'spatialResolution',   8, ...
%                          'whiteSignalToNoiseRatio', 0.05, ...
%                          'runBeamformer',       true, ...
%                          'dipoleOrientations',  []);
%
% See also: MEEG, FT_DIPOLESIMULATION. 


% ADDITIONAL SETTINGS - NOT IN HELP TEXT
%
% [DSIMULATED, SIMULATIONSPACE, RECONRESULTSOUT, BEAMFORMEDOIL] = 
%                          OSL_SIMULATE_MEG_DATA(..., 'runBeamformer', TRUE)
%   runs DSIMULATED through the oil source reconstruction pipeline,
%   performing source reconstruction and enveloping. The resulting oil
%   structure is returned in BEAMFORMEDOIL. 
%
% [DSIMULATED, SIMULATIONSPACE, RECONRESULTSOUT, BEAMFORMEDOIL, DEBUGRESULTS] = 
%                              OSL_SIMULATE_MEG_DATA(..., 'debugMode', TRUE)
%   runs the simulation in debug mode. 
%   If beamforming is being run on the simulated data, a simple LCMV 
%   beamformer will also be run for comparison. The dipole magnitudes and 
%   neural activity index over the simulation grid are returned in 
%   DEBUGRESULTS. 
%   Further, plots will be made of power over each channel in a topoplot, a
%   view of the simulated channel data is generated, a 3D plot of the brain
%   grid, dipole locations and sensor locations is produced, a couple of 
%   lead fields are displayed, the fit between simulated and reconstructed 
%   signals is assessed and the neural activity index over the simulation 
%   grid returned by both the LCMV beamformer and the oil beamformer are 
%   saved as nifti files and compared. 
%
% [...] = OSL_SIMULATE_MEG_DATA(..., 'Parameter', 'Value') further options:
%    'matchTemplateExactly' - All channels in the template are reproduced
%                             in the simulated object, rather than 
%                             stripping out channels not holding simulated 
%                             data. [false]
%                             This can be useful when debugging. 
%
%    'sourceReconSaveFile'  - file name for saving the source 
%                             reconstruction results structure 
%                             RECONRESULTSOUT to disc. 


% FUNCTION ALGORITHM:
% 1. Read in, check and format all inputs.
% 
% 2. Load the template MEEG object. Construct from it a blank, temporary
%    MEEG object, containing the same metadata. 
%
% 3. Run the temporary object through source reconstruction in osl, with
%    the appropriate structural file, reconstruction method and spatial
%    resolution. This provides the simulation grid for the problem, and the
%    lead fields between the gridpoints and MEG sensors. 
%
% 4. Map the dipole positions to the closest points on the simulation grid.
%    Determine dipole orientations as perpendicular to the cortex.
%    Propagate the signals from the dipoles to the MEG sensors using the
%    lead fields. Add white and/or structured noise in the sensors. 
%
% 5. Package up the simulated data in a new MEEG object. Strip out any
%    channels not holding simulated data. Ensure internal consistency. 
%
% 6. If desired, run the simulated data through osl's source
%    reconstruction. Save/output the results. 
%
% 7. If in debug mode, also run a simple LCMV beamformer as a check on the
%    reconstruction. Produce a variety of diagnostic plots. 
%
% NOTE ON USAGE:
%   This function has been mainly tested using ctf data templates, 
%   for continuous simulations. Simulating multiple trials or using  
%   Neuromag data templates have been tested, but less extensively. 
%
%   Please report any bugs to giles.colclough 'at' magd.ox.ac.uk
%
%   The necessary subfunctions are stored in the MEGsim package, in folder
%   '+MEGsim'. Changing the folder name will cause this function to break.
%   Ensure the package folder is on the Matlab path. 
%
%   This software was written and tested using Matlab versions 8.0 and 8.2.
%   Users of Matlab versions 7.10 and earlier will hit errors at the
%   ismatrix function. 


% UNTESTED, UNDOCUMENTED SETTINGS
%
% [...] = OSL_SIMULATE_MEG_DATA(..., 'Parameter', 'Value') further options
%   allow the setting of channels, sensors, trials and fiducials fields of
%   the new meeg object. This functionality has not been tested. It is not
%   guaranteed that the total integrity of the object will be confirmed
%   after some fields are altered. 
%    'channels'  - channels structure
%    'sensors'   - sensors structure
%    'fiducials' - fiducials structure
%    'trials'    - structure of length equal to number of trials. May have
%                  fields 'trialonset', a scalar indexing the trial onset
%                  time, 'label', a string setting the condition for the 
%                  trial, and 'events', which holds a structure describing
%                  the events for each trial. 
%                  If only one trial is done, this is still the method for
%                  setting the event information. 


%	Copyright 2014 OHBA
%	This program is free software: you can redistribute it and/or modify
%	it under the terms of the GNU General Public License as published by
%	the Free Software Foundation, either version 3 of the License, or
%	(at your option) any later version.
%	
%	This program is distributed in the hope that it will be useful,
%	but WITHOUT ANY WARRANTY; without even the implied warranty of
%	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
%	GNU General Public License for more details.
%	
%	You should have received a copy of the GNU General Public License
%	along with this program.  If not, see <http://www.gnu.org/licenses/>.


%	$LastChangedBy: GilesColclough $
%	$Revision: 317 $
%	$LastChangedDate: 2014-02-19 16:11:13 +0000 (Wed, 19 Feb 2014) $
%	Contact: giles.colclough 'at' magd.ox.ac.uk
%	Originally written on: GLNXA64 by Giles Colclough, 25-Oct-2013 12:43:45


%% Parse inputs
InputParams = MEGsim.assign_inputs(varargin{:});

Dtemplate          = InputParams.templateMEEGfile; % spm MEEG object to use as template
doBeamformer       = InputParams.doBeamformer;     % choose to run beamformer at the end
saveFile           = InputParams.saveFileName;
reconResFileName   = InputParams.reconResFileName;

% allow for a debug mode
DEBUG              = InputParams.DEBUG;
if DEBUG, fprintf('OSL_SIMULATE_MEG_DATA: Running in DEBUG mode. \n'); end

% initialise random number seed
if verLessThan('matlab', '7.12'), 
    % some people in OHBA still have old matlab 
    rand('seed', InputParams.rndSeed);                                     %#ok<RAND> 
else
    rng(InputParams.rndSeed, 'twister');
end%if

%% Set up MEEG object
fprintf('Loading in MEEG template. \n\n');
% load in template
if ischar(Dtemplate),
    Dtemplate = spm_eeg_load(Dtemplate);
end%if

[saveDir, saveFileName] = fileparts(saveFile);
if ~isdir(saveDir), mkdir(saveDir); end

% use a temporary meeg object for source recon with user-supplied changes
% to template
tmpFile = fullfile(saveDir, [saveFileName '_tmp']);

P = InputParams;
if isempty(P.channels), % channels structure not changed
    P.nChannels = nchannels(Dtemplate);
else % user-specified channels
    P.nChannels = length(P.channels);
end

% copy across with user-desired changes to fiducials & sensors etc.
Dtmp = MEGsim.create_new_meeg_object(Dtemplate, tmpFile, P);

% cleanup at function return
cleanUp = onCleanup(@() delete(Dtmp));

%% Find co-ordinate space and lead fields

isBFprovided = isfield(P, 'beamformerResults') && ...
               ~isempty(P.beamformerResults)   && ...
               isstruct(P.beamformerResults);
if isBFprovided,
    fprintf(['Using supplied co-ordinate space and lead fields ', ...
             'for simulation. \n\n']);
    
    % user-suplied beamforming results - included to speed up re-runs
    ReconResults = P.beamformerResults;
else
    % we will use oil source recon, using user-input parameters, to extract
    % the simulation grid and head model. 
    % 
    % Doing it this way ensures that dipoles are simlated using exactly the
    % same settings as are used when beamforming the simulated data. 
    
    fprintf(['Finding co-ordinate space and lead fields ', ...
             'for simulation. \n\n']);

    % run reconstruction on empty meeg object
    doEnveloping        = false;
    oil                 = MEGsim.setup_source_recon_params_for_blank_recon(P);
    [ReconResults, oil] = MEGsim.do_source_recon_using_osl(oil, tmpFile, ...
                                                    doEnveloping);
    
    % remove directory
    [status, res] = system(['rm -r ' oil.source_recon.dirname]);
    if status,
        error([mfilename ':DirCleanupFail'], ...
              ['Failed to remove source_recon directory. Message: \n ', ...
               res '\n']);
    end%if
end%if BF_provided

% extract co-ordinates and relevant data
brainCoords  = ReconResults.BF.sources.pos;
leadFields   = ReconResults.BF.sources.L.MEG;

% check consistency of lead fields and simulation space
assert(isequal(length(leadFields), size(brainCoords, 1)), ...
       [mfilename, ':WrongNumberOfLeadFields'], ...
       ['Something has gone wrong. Should be a leadfield for every ', ...
        'MNI coord. \n']);
    
%% Simulate signals
fprintf('Simulating MEG signal. \n\n'); 

% update channels
simulatedChannelInd = MEGsim.megchannels(Dtmp); % can't use logical indexing
nSimulatedChannels  = length(simulatedChannelInd);

% check provided lead fields match the template
if isBFprovided && ~isequal(nSimulatedChannels, size(leadFields{1},1)),
    error([mfilename ':InconsistentChannelsAndLFs'], ...
          ['It seems the provided lead fields from the beamformer ', ...
           'results do not match \n the number of MEG channels in ', ...
           'the template file. \n']);
end%if

% transform dipole locations from MNI space to head space
headDipolePositions = MEGsim.inverse_affine_transform_points(...
                         ReconResults.BF.data.transforms.toMNI, ...
                         P.dipolePositions);
                     
% find nearest positions to dipoles on mesh
% we do not check that this is not outside the brain, but the brainCoords
% should already be masked. 
[dipMeshInd, simulatedDipolePositions] = MEGsim.find_nearest_coordinate(...
                                          headDipolePositions, brainCoords);
                                      
% Make nifti of orignial dipole locations
dipLocationVector             = zeros(size(brainCoords, 1), 1);
dipLocationVector(dipMeshInd) = 1;

dipLocNiftiFileName = fullfile(saveDir, 'DipoleLocations');
nii.quicksave(dipLocationVector, dipLocNiftiFileName, P.spatialRes);

% create orientations if not provided
if isempty(P.dipoleOrientations),
    brainMesh          = ReconResults.BF.data.mesh.tess_mni;
    
    dipoleOrientations = MEGsim.get_orientations_from_mesh(...
                                      simulatedDipolePositions, brainMesh);
else
    dipoleOrientations = MEGsim.inverse_transform_dipole_orientation(...
                                 ReconResults.BF.data.transforms.toMNI, ...
                                 P.dipoleOrientations, ...
                                 P.dipolePositions, ...
                                 P.spatialRes / 2.0);
end%if

% generate data
[simData, dipoleSignals,data] = MEGsim.simulate_MEG_signal(leadFields, ...
                                                      P.nSamples, ...
                                                      nSimulatedChannels, ...
                                                      P.nTrials, ...
                                                      P.nDipoles, ...
                                                      P.fSample, ...
                                                      dipMeshInd, ...
                                                      dipoleOrientations, ...
                                                      P.signals, ...
                                                      P.SNR, ...
                                                      P.noiseLevel, ...
                                                      P.noiseBW, ...
                                                      P.emptyRoomCovariance, ...
                                                      P.roomNoiseSNR);

%% Create new object
fprintf('Packaging simulated data into a new object. \n\n');

outFileName = fullfile(saveDir, saveFileName);

% set additional parameters
P.trialData               = simData.trial;
P.simulatedChannelIndices = simulatedChannelInd;

Dsimulated = MEGsim.create_new_meeg_object(Dtmp, outFileName, P);

% check we have got all the data channels
unusedChanTypes = setxor(lower(chantype(Dtmp)), lower(chantype(Dsimulated)));
assert(~any(strncmpi('MEG', unusedChanTypes, 3)), ...
       [mfilename ':NotUsedAllMEEGChannels'], ...
       ['There are some data channels for which data have ', ...
        'not been simulated. \n']);

%% Run beamformer on simulated data?
if doBeamformer,    
    fprintf('Beamforming the simulated data. \n\n');
    
    % use mostly the same settings from above - taken care of in this
    % subfunction
    oil = MEGsim.setup_source_recon_params(P);
    
    % Run the source reconstruction (yes, again!), and envelope
    doEnveloping = true;
    [simDataReconResults, beamformedOil] = ...
        MEGsim.do_source_recon_using_osl(oil, outFileName, doEnveloping);
        
    
    % make nifti of neural activity index (NAI)
    sourceResults    = MEGsim.AB_get_source_timecourses(simDataReconResults, ...
                                                        'norecon');
    sourceVariance   = cell2mat(sourceResults.variance);
    
    varNiftiFileName = fullfile(saveDir, 'OILbeamformedNAI');
    nii.quicksave(sourceVariance, varNiftiFileName, P.spatialRes);
    
else
    beamformedOil       = [];
    simDataReconResults = [];
end%if

%% Run an LCMV beamformer for comparison
if doBeamformer && DEBUG,
    fprintf('  DEBUG: beamforming using LCMV. \n\n');
    
    NAIniftiFileName = fullfile(saveDir, 'LCMVbeamformedNAI');
    % just use first trial. It's easier. We're debugging here.
    iTrial = 1;
    
    % pull meg data from simulated object
    meegInd = MEGsim.megchannels(Dsimulated);
    Y       = Dsimulated(meegInd, :, iTrial);
    
    % zero phase iir filter to extract band of interest
    fBand       = beamformedOil.source_recon.freq_range;
    filterOrder = 5;
    filterType  = 'but'; % butterworth
    Y = ft_preproc_bandpassfilter(Y, ...
                                  P.fSample, ...
                                  fBand, ...
                                  filterOrder, ...
                                  filterType);
    % demean
    Y = bsxfun(@minus, Y, mean(Y,2));
    
    % beamform
    [LCMVdipoleMag, LCMVNAI] = MEGsim.LCMV_beamformer(Y, ...
                                                      leadFields, ...
                                                      P.spatialRes, ...
                                                      NAIniftiFileName, ...
                                                      true);
else
    LCMVdipoleMag = [];
    LCMVNAI       = [];
end%if

%% Make DEBUGGING PLOTS
if DEBUG,
    % we've put these in a subfunction
    MEGsim.make_debugging_plots(Dsimulated, ...
                                varNiftiFileName, ...
                                dipLocNiftiFileName, ...
                                beamformedOil, ...
                                ReconResults, ...
                                P, ...
                                brainCoords, ...
                                simulatedDipolePositions, ...
                                NAIniftiFileName, ...
                                simDataReconResults, ...
                                iTrial, ...
                                dipoleSignals, ...
                                LCMVdipoleMag, ...
                                dipMeshInd, ...
                                leadFields, ...
                                doBeamformer);
end%if DEBUG
%% Tidy output
              
% copy ReconResults from blank source recon into output, purely to
% allow easier re-runs of function.
if doBeamformer
    ReconResultsOut = simDataReconResults;
else
    ReconResultsOut = ReconResults;
end%if

% save BF results
if ~isempty(reconResFileName),
    if exist(fileparts(reconResFileName), 'dir');
        save(reconResFileName, 'ReconResultsOut', '-mat');
    else
        warning([mfilename ':ReconResDirDoesNotExist'], ...
                ['The directory specified for saving the source recon ', ...
                 'results does not exist. \n', ...
                 'The structure has not been saved. \n']);
    end%if
end

% transform mesh and dipole positions to MNI space
SimulationSpace.MNIbrainMesh = spm_eeg_inv_transform_points(...
                                   ReconResults.BF.data.transforms.toMNI, ...
                                   brainCoords);
                               
SimulationSpace.dipoleIndicesOnMesh   = dipMeshInd;
SimulationSpace.simulatedMNIdipolePos = spm_eeg_inv_transform_points(...
                           ReconResults.BF.data.transforms.toMNI, ...
                           simulatedDipolePositions);

% transform dipole orientations to MNI space
if isempty(InputParams.dipoleOrientations),
    MNIdipoleOrientations = MEGsim.transform_dipole_orientation( ...
                                 ReconResults.BF.data.transforms.toMNI, ...
                                 dipoleOrientations, ...
                                 simulatedDipolePositions, ...
                                 P.spatialRes / 2.0);
else % already in MNI space
    MNIdipoleOrientations = InputParams.dipoleOrientations;
end%if 

SimulationSpace.MNIdipoleOrientations = MNIdipoleOrientations;

% output debugging options
if nargout > 4,
    DebugResults.LCMVdipoleMag           = LCMVdipoleMag;
    DebugResults.LCMVNeuralActivityIndex = LCMVNAI;
end%if  

fprintf('\nSIMULATE_MEG_DATA: Simulation complete. \n\n');
end%OSL_simulate_MEG_data
% [EOF]
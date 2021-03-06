%% ===========================Authors Information =================%%
%    This code was originally developed by Lee E Clement for 
%    mono-msckf. Milad Ramezani has heavily modified the code   
%    and added additional components to be used for stereo-msckf.
%    Please cite properly if this code used for any academic and 
%    nonacademic purposes.

% @article{ramezani2018vehicle,
%   title={Vehicle positioning in GNSS-deprived urban areas by stereo visual-inertial odometry},
%   author={Ramezani, Milad and Khoshelham, Kourosh},
%   journal={IEEE Transactions on Intelligent Vehicles},
%   volume={3},
%   number={2},
%   pages={208--217},
%   year={2018},
%   publisher={IEEE}
% }
%% ============================Notation============================ %%
% X_sub_super
% q_ToFrom
% p_ofWhat_expressedInWhatFrame


%% =============================Setup============================== %%
clear;
close all;
clc;
addpath('Desktop/Stereo-VIO/stereo-msckf/utils');

tic
dataDir = 'Desktop/Stereo-VIO/datasets';

% fileName = 'dataset3';kStart = 1; kEnd = 150;
% fileName = 'dataset3_fresh_10noisy';kStart = 2; kEnd = 98;
% fileName = 'dataset3_fresh_10lessnoisy';
% fileName = 'dataset3_fresh_20lessnoisy';
% fileName = 'dataset3_fresh_40lessnoisy';
% fileName = 'dataset3_fresh_60lessnoisy';
% fileName = 'dataset3_fresh_80lessnoisy';
% fileName = 'dataset3_fresh_100lessnoisy';
% fileName = 'dataset3_fresh_500lessnoisy';
% fileName = '2011_09_26_drive_0035_sync_KLT';kStart = 2; kEnd = 98;
fileName = '2011_09_26_drive_0005_sync_KLT';kStart = 2; kEnd = 150;
% fileName = '2011_09_30_drive_0020_sync_KLT';
% fileName = '2011_09_26_drive_0027_sync_KLT';
% fileName = '2011_09_30_drive_0020_sync_KLT'; kStart = 2; kEnd = 330;

% Good KITTI runs
% fileName = '2011_09_26_drive_0001_sync_KLT'; kStart = 2; kEnd = 108;% Stereo result with the infor of second cam

% fileName = '2011_09_26_drive_0036_sync_KLT'; kStart = 2; kEnd = 239;% y_var = 20, mintrack=4;
% fileName = '2011_09_26_drive_0051_sync_KLT'; kStart = 2; kEnd = 114;
% fileName = '2011_09_26_drive_0095_sync_KLT'; kStart = 2; kEnd = 139;

% Calibration between left and right gray scale camera
% 1 represents left and 2 represents right
camera.C_C2_C1 = [9.993513e-01 1.860866e-02 -3.083487e-02;
                 -1.887662e-02 9.997863e-01 -8.421873e-03;
                  3.067156e-02 8.998467e-03 9.994890e-01];
camera.q_C2C1 = rotMatToQuat(camera.C_C2_C1);       
camera.p_C1_C2 = [-5.37*10^-1; 4.822061*10^-3; -1.252488*10^-2];      

load(sprintf('%s/%s.mat',dataDir,fileName));

% Calibration between vel, imu and cam
% C_v_I : imutovel, p_I_v ; imutovel
% C_c_v : veltocam, p_c_v ; veltocam
p_v_I = [-0.80868      0.31956     -0.79972]';
p_c_v = [-0.0040698    -0.076316     -0.27178]';
C_v_I = [9.999976e-01 7.553071e-04 -2.035826e-03;-7.854027e-04 9.998898e-01 -1.482298e-02;
2.024406e-03 1.482454e-02 9.998881e-01];
C_c_v =[7.533745e-03 -9.999714e-01 -6.166020e-04;1.480249e-02 7.280733e-04 -9.998902e-01;
9.998621e-01 7.523790e-03 1.480755e-02];
p_C_I = C_v_I'*(-C_c_v'*p_c_v - p_v_I);

% for going from IMU to cam
C_c_I = C_c_v*C_v_I;
% C_c_I = C_c_v;

% r_i_vk_i = p_vi_i;

%Dataset window bounds
% kStart = 2; kEnd = 177;
% kStart = 1215; kEnd = 1715;

%Set constant
numLandmarks = size(y_k_j,3);

%Set up the camera parameters
camera.c_u      = cu;                   % Principal point [u pixels]
camera.c_v      = cv;                   % Principal point [v pixels]
camera.f_u      = fu;                   % Focal length [u pixels]
camera.f_v      = fv;                   % Focal length [v pixels]
camera.b        = b;                    % Stereo baseline [m]
camera.q_CI     = rotMatToQuat(C_c_I);  % 4x1 IMU-to-Camera rotation quaternion
C_c2_I = camera.C_C2_C1*C_c_I;
camera.p_C_I    = p_C_I;            % 3x1 Camera position in IMU frame

camera.q2_CI   = rotMatToQuat(C_c2_I); % 4x1 IMU-to-Camera rotation quaternion for the second cam
camera.p2_C_I    = camera.p_C_I + C_c2_I'*(-camera.p_C1_C2); % 3x1 Camera position in IMU frame for the second cam


%Set up the noise parameters
% y_var can have a big impact on final result!!!!
y_var = 11^2 * ones(1,4);               % pixel coord var
noiseParams.u_var_prime = y_var(1)/camera.f_u^2;
noiseParams.v_var_prime = y_var(2)/camera.f_v^2;

w_var = 4e-2 * ones(1,3);               % rot vel var
v_var = 4e-2 * ones(1,3);               % lin vel var
dbg_var = 1e-6 * ones(1,3);            % gyro bias change var
dbv_var = 1e-6 * ones(1,3);            % vel bias change var
noiseParams.Q_imu = diag([w_var, dbg_var, v_var, dbv_var]);

q_var_init = 1e-6 * ones(1,3);         % init rot var
p_var_init = 1e-6 * ones(1,3);         % init pos var
bg_var_init = 1e-6 * ones(1,3);        % init gyro bias var
bv_var_init = 1e-6 * ones(1,3);        % init vel bias var
noiseParams.initialIMUCovar = diag([q_var_init, bg_var_init, bv_var_init, p_var_init]);
   
% MSCKF parameters
msckfParams.minTrackLength = 5;        % Set to inf to dead-reckon only
msckfParams.maxTrackLength = inf;      % Set to inf to wait for features to go out of view
msckfParams.maxGNCostNorm  = 1e-2;     % Set to inf to allow any triangulation, no matter how bad
msckfParams.minRCOND       = 1e-12;
msckfParams.doNullSpaceTrick = false;
msckfParams.doQRdecomp = true;


% IMU state for plotting etc. Structures indexed in a cell array
imuStates = cell(1,numel(t));
prunedStates = {};

% imuStates{k}.q_IG         4x1 Global to IMU rotation quaternion
% imuStates{k}.p_I_G        3x1 IMU Position in the Global frame
% imuStates{k}.b_g          3x1 Gyro bias
% imuStates{k}.b_v          3x1 Velocity bias
% imuStates{k}.covar        12x12 IMU state covariance

% We don't really need these outside of msckfState, do we?
% camState = cell(1,numel(t));
% camStates{k}.q_CG        4x1 Global to camera rotation quaternion
% camStates{k}.p_C_G       3x1 Camera Position in the Global frame
% camStates{k}.trackedFeatureIds  1xM List of feature ids that are currently being tracked from that camera state

%msckfState.imuState
%msckfState.imuCovar
%msckfState.camCovar
%msckfState.imuCamCovar
%msckfState.camStates
%msckfState.camCamCovar  do we need that?....

% Measurements as structures all indexed in a cell array
dT = [0, diff(t)];
measurements = cell(1,numel(t));
% groundTruthStates = cell(1,numel(t));
% groundTruthMap = rho_i_pj_i;

% Important: Because we're idealizing our pixel measurements and the
% idealized measurements could legitimately be -1, replace our invalid
% measurement flag with NaN
y_k_j(y_k_j == -1) = NaN;

for state_k = kStart:kEnd 
    measurements{state_k}.dT    = dT(state_k);                      % sampling times
    measurements{state_k}.y_L     = squeeze(y_k_j(1:2,state_k,:));    % left camera 
    
    measurements{state_k}.y_R     = squeeze(y_k_j(3:4,state_k,:));    % right camera 
    measurements{state_k}.omega = w_vk_vk_i(:,state_k);             % ang vel
    measurements{state_k}.v     = v_vk_vk_i(:,state_k);             % lin vel
    
    %Idealize measurements
    validMeas = ~isnan(measurements{state_k}.y_L(1,:));
    measurements{state_k}.y_L(1,validMeas) = (measurements{state_k}.y_L(1,validMeas) - camera.c_u)/camera.f_u;
    measurements{state_k}.y_L(2,validMeas) = (measurements{state_k}.y_L(2,validMeas) - camera.c_v)/camera.f_v;
    
    validMeas = ~isnan(measurements{state_k}.y_R(1,:));
    measurements{state_k}.y_R(1,validMeas) = (measurements{state_k}.y_R(1,validMeas) - camera.c_u)/camera.f_u;
    measurements{state_k}.y_R(2,validMeas) = (measurements{state_k}.y_R(2,validMeas) - camera.c_v)/camera.f_v;
    %Ground Truth
    q_IG = rotMatToQuat(axisAngleToRotMat(theta_vk_i(:,state_k))); % Rotations from Global to Inertial
    p_I_G = r_i_vk_i(:,state_k); 
    % position from Global to Inertial frame
    
    groundTruthStates{state_k}.imuState.q_IG = q_IG;
    groundTruthStates{state_k}.imuState.p_I_G = p_I_G;
    
    % Compute camera pose from current IMU pose
    C_IG = quatToRotMat(q_IG);
    q_CG = quatLeftComp(camera.q_CI) * q_IG;
    q2_CG = quatLeftComp(camera.q2_CI) * q_IG; % For the second cam
    p_C_G = p_I_G + C_IG' * camera.p_C_I;
    
    p2_C_G = p_I_G + C_IG' * camera.p2_C_I;  % For the second cam
    
    groundTruthStates{state_k}.camState.q_CG = q_CG;
    groundTruthStates{state_k}.camState.p_C_G = p_C_G;
    
    groundTruthStates{state_k}.camState.q2_CG = q2_CG;  % For the second cam
    groundTruthStates{state_k}.camState.p2_C_G = p2_C_G;
    
end

% keyboard
%Struct used to keep track of features
featureTracks_L = {};
trackedFeatureIds_L = [];

featureTracks_R = {};       % For the second cam
trackedFeatureIds_R = [];

% featureTracks = {track1, track2, ...}
% track.featureId 
% track.observations


%% ==========================Initial State======================== %%
%Use ground truth for first state and initialize feature tracks with
%feature observations
%Use ground truth for the first state

firstImuState.q_IG = rotMatToQuat(axisAngleToRotMat(theta_vk_i(:,kStart)));
firstImuState.p_I_G = r_i_vk_i(:,kStart);
% firstImuState.q_IG = [0;0;0;1];
% firstImuState.q_IG = rotMatToQuat(rotx(90));
% firstImuState.p_I_G = [0;0;0];
% keyboard
[msckfState, featureTracks_L, trackedFeatureIds_L, featureTracks_R,...
trackedFeatureIds_R] = initializeMSCKF(firstImuState, measurements{kStart}, camera, kStart, noiseParams);
imuStates = updateStateHistory(imuStates, msckfState, camera, kStart);
msckfState_imuOnly{kStart} = msckfState;

%% ============================MAIN LOOP========================== %%

numFeatureTracksResidualized_L = 0;
numFeatureTracksResidualized_R = 0;
map_L = [];
map_R = [];

for state_k = kStart:(kEnd-1)
    fprintf('state_k = %4d\n', state_k);
    
    %% ==========================STATE PROPAGATION======================== %%
    
    %Propagate state and covariance
    msckfState = propagateMsckfStateAndCovar(msckfState, measurements{state_k}, noiseParams);
    msckfState_imuOnly{state_k+1} = propagateMsckfStateAndCovar(msckfState_imuOnly{state_k}, measurements{state_k}, noiseParams);
    
    %Add camera pose to msckfState
    msckfState = augmentState(msckfState, camera, state_k+1);
    
    
    %% ==========================FEATURE TRACKING======================== %%
    % Add observations to the feature tracks, or initialize a new one
    % If an observation is -1, add the track to featureTracksToResidualize
    featureTracksToResidualize_L = {};
    featureTracksToResidualize_R = {}; % for the second cam
    
    for featureId = 1:numLandmarks
        %IMPORTANT: state_k + 1 not state_k
%         keyboard
        meas_L_k = measurements{state_k+1}.y_L(:, featureId);
        
        meas_R_k = measurements{state_k+1}.y_R(:, featureId);
        
        outOfView = isnan(meas_L_k(1,1));
        
        if ismember(featureId, trackedFeatureIds_L)

            if ~outOfView
                %Append observation and append id to cam states tomorrow
                %from here ......
                featureTracks_L{trackedFeatureIds_L == featureId}.observations_L(:, end+1) = meas_L_k;
                
                featureTracks_R{trackedFeatureIds_R == featureId}.observations_R(:, end+1) = meas_R_k;
                
                %Add observation to current camera
                msckfState.camStates_L{end}.trackedFeatureIds_L(end+1) = featureId;
                msckfState.camStates_R{end}.trackedFeatureIds_R(end+1) = featureId;
            end
            
            track_L = featureTracks_L{trackedFeatureIds_L == featureId};
            track_R = featureTracks_R{trackedFeatureIds_R == featureId};
            
            if outOfView ...
                    || size(track_L.observations_L, 2) >= msckfParams.maxTrackLength ...
                    || state_k+1 == kEnd
                                
                %Feature is not in view, remove from the tracked features
                [msckfState, camStates_L, camStateIndices_L] = removeTrackedFeature_L(msckfState, featureId);
                [msckfState, camStates_R, camStateIndices_R] = removeTrackedFeature_R(msckfState, featureId);
                
                %Add the track, with all of its camStates, to the
                %residualized list
%                 keyboard
                if length(camStates_L) >= msckfParams.minTrackLength
                    track_L.camStates_L = camStates_L;
                    track_L.camStateIndices = camStateIndices_L;
                    featureTracksToResidualize_L{end+1} = track_L;
                    track_R.camStates_R = camStates_R; % for the second cam
                    track_R.camStateIndices = camStateIndices_R; % ....
                    featureTracksToResidualize_R{end+1} = track_R; % ...
                    
                end
               
                %Remove the track
                featureTracks_L = featureTracks_L(trackedFeatureIds_L ~= featureId);
                trackedFeatureIds_L(trackedFeatureIds_L == featureId) = []; 
                
                featureTracks_R = featureTracks_R(trackedFeatureIds_R ~= featureId);
                trackedFeatureIds_R(trackedFeatureIds_R == featureId) = []; 
            end
            
        elseif ~outOfView && state_k+1 < kEnd % && ~ismember(featureId, trackedFeatureIds)
            %Track new feature
            track_L.featureId = featureId; track_R.featureId = featureId;
            track_L.observations_L = meas_L_k; track_R.observations_R = meas_R_k;
            featureTracks_L{end+1} = track_L; 
            trackedFeatureIds_L(end+1) = featureId; 
            
            featureTracks_R{end+1} = track_R; % for the second cam
            trackedFeatureIds_R(end+1) = featureId;


            %Add observation to current camera
            msckfState.camStates_L{end}.trackedFeatureIds_L(end+1) = featureId;
            
            msckfState.camStates_R{end}.trackedFeatureIds_R(end+1) = featureId;
        end
    end

%     keyboard
    
    %% ==========================FEATURE RESIDUAL CORRECTIONS======================== %%
    if ~isempty(featureTracksToResidualize_L)
        H_o = [];
        r_o = [];
        R_o = [];

        for f_i = 1:length(featureTracksToResidualize_L)

            track_L = featureTracksToResidualize_L{f_i};
            track_R = featureTracksToResidualize_R{f_i};
            %Estimate feature 3D location through Gauss Newton inverse depth
            %optimization
            [p_f_G, Jcost_L, RCOND_L] = calcGNPosEst_L(track_L.camStates_L, track_L.observations_L, noiseParams);
            [p2_f_G, Jcost_R, RCOND_R] = calcGNPosEst_R(track_R.camStates_R, track_R.observations_R, noiseParams); % For the second cam
            % Uncomment to use ground truth map instead
%              p_f_G = groundTruthMap(:, track.featureId); Jcost = 0; RCOND = 1;
%              p_f_C = triangulate(squeeze(y_k_j(:, track.camStates{1}.state_k, track.featureId)), camera); Jcost = 0; RCOND = 1;
        % If RCNOND is close to 1 it means the estimate is well-conditioned
            nObs = size(track_L.observations_L,2);
            JcostNorm_L = Jcost_L / nObs^2;
            JcostNorm_R = Jcost_R / nObs^2; % For the second cam
            fprintf('Jcost_R = %f | JcostNorm_R = %f | RCOND_R = %f\n',...
                Jcost_R, JcostNorm_R,RCOND_R);
            fprintf('Jcost_L = %f | JcostNorm_L = %f | RCOND_L = %f\n',...
                Jcost_L, JcostNorm_L,RCOND_L);
            
            if JcostNorm_L > msckfParams.maxGNCostNorm ...
                    || RCOND_L < msckfParams.minRCOND
%                     || norm(p_f_G) > 50
                
                break;
            else
                
             if JcostNorm_R > msckfParams.maxGNCostNorm ...
                    || RCOND_R < msckfParams.minRCOND
%                     || norm(p_f_G) > 50
                
                break;
            else
                map_L(:,end+1) = p_f_G;
                map_R(:,end+1) = p2_f_G;
                numFeatureTracksResidualized_L = numFeatureTracksResidualized_L + 1;
                numFeatureTracksResidualized_R = numFeatureTracksResidualized_R + 1; % For the second cam
                fprintf('Using new feature track with %d observations. Total track count = %d.\n',...
                    nObs, numFeatureTracksResidualized_L);
             end
            end
            % how can I combine 2 cams together from here :( ??????????
            %Calculate residual and Hoj 
%             [r_j] = calcResidual(p_f_G,p2_f_G,track_L.camStates_L, track_R.camStates_R, track_L.observations_L, track_R.observations_R);
            [r1_j] = calcResidual_L(p_f_G, track_L.camStates_L, track_L.observations_L);
            [r2_j] = calcResidual_R(p2_f_G, track_R.camStates_R, track_R.observations_R); % For the second cam
            r_j = [r1_j; r2_j];


%             R_j = diag(repmat([noiseParams.u_var_prime, noiseParams.v_var_prime], [1, numel(r_j)/2]));
            R1_j = repmat([noiseParams.u_var_prime, noiseParams.v_var_prime], [1, numel(r1_j)/2]);
            R2_j = repmat([noiseParams.u_var_prime, noiseParams.v_var_prime], [1, numel(r2_j)/2]);
            R_j = diag([R1_j, R2_j]);
            
%             keyboard 
            
            
            [H_o_j, A_j, H_x_j] = calcHoj(p_f_G, p2_f_G, msckfState, track_L.camStateIndices);
            % Stacked residuals and friends
            if msckfParams.doNullSpaceTrick
                H_o = [H_o; H_o_j];

                if ~isempty(A_j)
                    r_o_j = A_j' * r_j;
                    r_o = [r_o ; r_o_j];

                    R_o_j = A_j' * R_j * A_j;
                    R_o(end+1 : end+size(R_o_j,1), end+1 : end+size(R_o_j,2)) = R_o_j;
                end
                
            else
                H_o = [H_o; H_x_j];
                r_o = [r_o; r_j];
                R_o(end+1 : end+size(R_j,1), end+1 : end+size(R_j,2)) = R_j;
            end
        end
        
        if ~isempty(r_o)
            % Put residuals into their final update-worthy form
            if msckfParams.doQRdecomp
                [T_H, Q_1] = calcTH(H_o);
                r_n = Q_1' * r_o;
                R_n = Q_1' * R_o * Q_1;
            else
                T_H = H_o;
                r_n = r_o;
                R_n = R_o;
            end           
            
            % Build MSCKF covariance matrix
%             P = [msckfState.imuCovar, msckfState.imuCamCovar;
%                    msckfState.imuCamCovar', msckfState.camCovar];
              P = [msckfState.imuCovar, msckfState.imuCamCovar, msckfState.imuCamCovar;
                   msckfState.imuCamCovar', msckfState.camCovar, msckfState.camCovar; 
                   msckfState.imuCamCovar', msckfState.camCovar', msckfState.camCovar]; % the covariance for 3 sensors

            % Calculate Kalman gain
            K = (P*T_H') / ( T_H*P*T_H' + R_n ); % == (P*T_H') * inv( T_H*P*T_H' + R_n )

            % State correction
            deltaX = K * r_n;
            msckfState = updateState(msckfState, deltaX);

            % Covariance correction
            tempMat = (eye(12 + 2*6*size(msckfState.camStates_L,2)) - K*T_H);
%             tempMat = (eye(12 + 6*size(msckfState.camStates,2)) - K*H_o);
% if state_k == 47
%             keyboard
%         end

            P_corrected = tempMat * P * tempMat' + K * R_n * K';
            Nn = size(msckfState.camStates_L,2);
% keyboard
            msckfState.imuCovar = P_corrected(1:12,1:12);
            msckfState.camCovar = P_corrected(13:end-6*(Nn),13:end-6*(Nn));
            msckfState.imuCamCovar = P_corrected(1:12, 13:end-6*(Nn));
           
%             figure(1); clf; imagesc(deltaX); axis equal; axis ij; colorbar;
%             drawnow;
            
        end
        
    end
    
        %% ==========================STATE HISTORY======================== %% 
        imuStates = updateStateHistory(imuStates, msckfState, camera, state_k+1);
        
        
        %% ==========================STATE PRUNING======================== %%
        %Remove any camera states with no tracked features
%         if state_k == 2
%             keyboard
%         end
        [msckfState, deletedCamStates_L, deletedCamStates_R] = pruneStates(msckfState);
        
        % Something is wrong here !!!! I found the problem; it is from
        % deletedCamStates
        if ~isempty(deletedCamStates_L)
            prunedStates(end+1:end+length(deletedCamStates_L)) = deletedCamStates_L;    
        end    
        
%         if max(max(msckfState.imuCovar(1:12,1:12))) > 1
%             disp('omgbroken');
%         end
        
        plot_traj;
%     figure(2); imagesc(msckfState.imuCovar(1:12,1:12)); axis equal; axis ij; colorbar;
%     drawnow;
end %for state_K = ...

toc


%% ==========================PLOT ERRORS======================== %%
kNum = length(prunedStates);
p_C_G_est = NaN(3, kNum);
p_I_G_imu = NaN(3, kNum);
p_C_G_imu = NaN(3, kNum);
p_C_G_GT = NaN(3, kNum);
theta_CG_err = NaN(3,kNum);
theta_CG_err_imu = NaN(3,kNum);
err_sigma = NaN(6,kNum); % cam state is ordered as [rot, trans]
err_sigma_imu = NaN(6,kNum);
% 
tPlot = NaN(1, kNum);
% 
for k = 1:kNum
    state_k = prunedStates{k}.state_k;
    
    p_C_G_GT(:,k) = groundTruthStates{state_k}.camState.p_C_G;
    p_C_G_est(:,k) = prunedStates{k}.p_C_G;
    q_CG_est  = prunedStates{k}.q_CG;    
    
    theta_CG_err(:,k) = crossMatToVec( eye(3) ...
                    - quatToRotMat(q_CG_est) ...
                        * ( C_c_v * axisAngleToRotMat(theta_vk_i(:,kStart+k-1)) )' );
      
    err_sigma(:,k) = prunedStates{k}.sigma;
    imusig = sqrt(diag(msckfState_imuOnly{state_k}.imuCovar));
    err_sigma_imu(:,k) = imusig([1:3,10:12]);
    
    p_I_G_imu(:,k) = msckfState_imuOnly{state_k}.imuState.p_I_G;
    C_CG_est_imu = C_CI * quatToRotMat(msckfState_imuOnly{state_k}.imuState.q_IG);
    theta_CG_err_imu(:,k) = crossMatToVec( eye(3) ...
                    - C_CG_est_imu ...
                        * ( C_CI * axisAngleToRotMat(theta_vk_i(:,kStart+k-1)) )' );
                    
    tPlot(k) = t(state_k);
end

% p_I_G_GT = p_vi_i(:,kStart:kEnd);
p_I_G_GT = r_i_vk_i(:,kStart:kEnd);
p_C_G_GT = p_I_G_GT + repmat(rho_v_c_v,[1,size(p_I_G_GT,2)]);
p_C_G_imu = p_I_G_imu + repmat(rho_v_c_v,[1,size(p_I_G_imu,2)]);

rotLim = [-0.5 0.5];
transLim = [-0.5 0.5];

% Save estimates
msckf_trans_err = p_C_G_est - p_C_G_GT;
msckf_rot_err = theta_CG_err;
imu_trans_err = p_C_G_imu - p_C_G_GT;
imu_rot_err = theta_CG_err_imu;
save(sprintf('Desktop/Stereo-VIO-073baedaee47b5073777f4704c998736f6d52627\Stereo-VIO-073baedaee47b5073777f4704c998736f6d52627/KITTI Trials/msckf_%s', fileName));

armse_trans_msckf = mean(sqrt(sum(msckf_trans_err.^2, 1)/3));
rmse_trans_msckf = sqrt(sum(msckf_trans_err.^2, 1)/3);
armse_rot_msckf = mean(sqrt(sum(msckf_rot_err.^2, 1)/3));
rmse_rot_msckf = sqrt(sum(msckf_rot_err.^2, 1)/3);
final_trans_err_msckf = norm(msckf_trans_err(:,end));

armse_trans_imu = mean(sqrt(sum(imu_trans_err.^2, 1)/3));
rmse_trans_imu = sqrt(sum(imu_trans_err.^2, 1)/3);
armse_rot_imu = mean(sqrt(sum(imu_rot_err.^2, 1)/3));
rmse_rot_imu = sqrt(sum(imu_rot_err.^2, 1)/3);
final_trans_err_imu = norm(imu_trans_err(:,end));

fprintf('Trans ARMSE: IMU %f, MSCKF %f\n',armse_trans_imu, armse_trans_msckf);
fprintf('Rot ARMSE: IMU %f, MSCKF %f\n',armse_rot_imu, armse_rot_msckf);
fprintf('Final Trans Err: IMU %f, MSCKF %f\n',final_trans_err_imu, final_trans_err_msckf);

% Translation Errors
figure
subplot(3,1,1)
plot(tPlot, p_C_G_est(1,:) - p_C_G_GT(1,:), 'LineWidth', 2)
hold on
plot(tPlot, 3*err_sigma(4,:), '--r')
plot(tPlot, -3*err_sigma(4,:), '--r')
% ylim(transLim)
xlim([tPlot(1) tPlot(end)])
title('Translational Error')
ylabel('\delta r_x')


subplot(3,1,2)
plot(tPlot, p_C_G_est(2,:) - p_C_G_GT(2,:), 'LineWidth', 2)
hold on
plot(tPlot, 3*err_sigma(5,:), '--r')
plot(tPlot, -3*err_sigma(5,:), '--r')
% ylim(transLim)
xlim([tPlot(1) tPlot(end)])
ylabel('\delta r_y')

subplot(3,1,3)
plot(tPlot, p_C_G_est(3,:) - p_C_G_GT(3,:), 'LineWidth', 2)
hold on
plot(tPlot, 3*err_sigma(6,:), '--r')
plot(tPlot, -3*err_sigma(6,:), '--r')
% ylim(transLim)
xlim([tPlot(1) tPlot(end)])
ylabel('\delta r_z')
xlabel('t_k')

% Rotation Errors
figure
subplot(3,1,1)
plot(tPlot, theta_CG_err(1,:), 'LineWidth', 2)
hold on
plot(tPlot, 3*err_sigma(1,:), '--r')
plot(tPlot, -3*err_sigma(1,:), '--r')
ylim(rotLim)
xlim([tPlot(1) tPlot(end)])
title('Rotational Error')
ylabel('\delta \theta_x')


subplot(3,1,2)
plot(tPlot, theta_CG_err(2,:), 'LineWidth', 2)
hold on
plot(tPlot, 3*err_sigma(2,:), '--r')
plot(tPlot, -3*err_sigma(2,:), '--r')
ylim(rotLim)
xlim([tPlot(1) tPlot(end)])
ylabel('\delta \theta_y')

subplot(3,1,3)
plot(tPlot, theta_CG_err(3,:), 'LineWidth', 2)
hold on
plot(tPlot, 3*err_sigma(3,:), '--r')
plot(tPlot, -3*err_sigma(3,:), '--r')
ylim(rotLim)
xlim([tPlot(1) tPlot(end)])
ylabel('\delta \theta_z')
xlabel('t_k')
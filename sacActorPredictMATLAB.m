function delta_T = sacActorPredictMATLAB(obs, actorFile)
% sacActorPredictMATLAB
% Runs exported SAC actor network in MATLAB.
%
% Input:
%   obs = 1x9 observation vector:
%       [sigma_rssi_bar, sigma_gps_bar, snr_bar, plr_bar,
%        relative_speed_bar, relative_height_bar,
%        trusted_count, trust_bar, theta]
%
%   actorFile = path to sac_actor_export.mat
%
% Output:
%   delta_T = threshold adjustment predicted by SAC actor

persistent actor cachedFile

% Load actor only once
if isempty(actor) || isempty(cachedFile) || ~strcmp(cachedFile, actorFile)
    actor = load(actorFile);
    cachedFile = actorFile;
end

% Make sure obs is row vector
x = double(obs(:)');

% ============================================================
% Observation normalization from VecNormalize
% obs_norm = clip((obs - mean) / sqrt(var + epsilon))
% ============================================================

obs_mean = double(actor.obs_mean(:)');
obs_var = double(actor.obs_var(:)');
obs_epsilon = double(actor.obs_epsilon(1));
clip_obs = double(actor.clip_obs(1));

x = (x - obs_mean) ./ sqrt(obs_var + obs_epsilon);
x = max(min(x, clip_obs), -clip_obs);

% Convert to column vector for matrix multiplication
x = x(:);

% ============================================================
% Actor network forward pass
%
% Network:
% input(9)
% -> Linear(9,256)
% -> ReLU
% -> Linear(256,256)
% -> ReLU
% -> mu Linear(256,1)
% -> tanh
% -> scale to action range [-2,2]
% ============================================================

W1 = double(actor.latent_pi_0_weight);
b1 = double(actor.latent_pi_0_bias(:));

W2 = double(actor.latent_pi_2_weight);
b2 = double(actor.latent_pi_2_bias(:));

Wmu = double(actor.mu_weight);
bmu = double(actor.mu_bias(:));

% Layer 1
z1 = W1 * x + b1;
z1 = max(z1, 0);   % ReLU

% Layer 2
z2 = W2 * z1 + b2;
z2 = max(z2, 0);   % ReLU

% Mean action
mu = Wmu * z2 + bmu;

% Deterministic SAC action
action_squashed = tanh(mu);

% Scale action from [-1,1] to environment range [-2,2]
action_scale = double(actor.action_scale(1));
action_bias = double(actor.action_bias(1));

delta_T = action_bias + action_scale * action_squashed;

% Return scalar
delta_T = double(delta_T(1));
end
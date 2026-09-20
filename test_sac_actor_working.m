clc;
clear;
close all;

%% ============================================================
% TEST EXPORTED SAC ACTOR POLICY IN MATLAB
% Dynamic threshold generation for Phase 1
%
% This code checks:
%   observation -> sacActorPredictMATLAB -> delta_T -> new theta
%
% It uses the same 4 environments from our project:
%   0 = Perfect-NoNoise
%   1 = Open
%   2 = Suburban
%   3 = DenseUrban
%
% Required:
%   1. sacActorPredictMATLAB.m must be in the same folder or MATLAB path
%   2. sac_actor_export.mat must exist at actorFile path
%% ============================================================

%% ===== Actor file path =====

actorFile = "m:\AIforCyberSecurity\Project\models\sac_lam2_005\sac_actor_export.mat";

if ~isfile(actorFile)
    error("Actor file not found:\n%s", actorFile);
end

fprintf("\nActor file found:\n%s\n", actorFile);

%% ===== Output folder =====

outDir = "m:\AIforCyberSecurity\Project\models\sac_lam2_005\matlab_dynamic_threshold_test";

if ~isfolder(outDir)
    mkdir(outDir);
end

%% ===== Threshold settings =====

theta_static = 10;
theta_min = 1;
theta_max = 50;

%% ===== Simulation settings =====

T = 160;                 % total test time steps
currentTheta = theta_static;

envNames = ["Perfect-NoNoise","Open","Suburban","DenseUrban"];

% Environment schedule:
% 1-40   Perfect-NoNoise
% 41-80  Open
% 81-120 Suburban
% 121-160 DenseUrban
envSchedule = zeros(T,1);

envSchedule(1:40)     = 0;
envSchedule(41:80)    = 1;
envSchedule(81:120)   = 2;
envSchedule(121:160)  = 3;

%% ===== Storage =====

theta_old_log = zeros(T,1);
delta_T_log = zeros(T,1);
theta_new_log = zeros(T,1);

obsLog = zeros(T,9);
envIdLog = zeros(T,1);
envNameLog = strings(T,1);

%% ============================================================
% Main loop
%% ============================================================

fprintf("\n===== TESTING SAC DYNAMIC THRESHOLD GENERATION =====\n");

for t = 1:T

    envId = envSchedule(t);
    envName = envNames(envId + 1);

    %% ------------------------------------------------------------
    % Create project-style observation for each environment
    %
    % Observation format:
    % obs = [
    %   sigma_rssi_bar,
    %   sigma_gps_bar,
    %   snr_bar,
    %   plr_bar,
    %   relative_speed_bar,
    %   relative_height_bar,
    %   trusted_count,
    %   trust_bar,
    %   current_theta
    % ]
    %% ------------------------------------------------------------

    switch envId

        case 0
            % Perfect-NoNoise
            sigma_rssi_bar = 0.5 + 0.05*randn;
            sigma_gps_bar  = 0.2 + 0.03*randn;
            snr_bar = 100 + 2*randn;
            plr_bar = 0.00 + 0.001*randn;
            relative_speed_bar = 0.5 + 0.1*randn;
            relative_height_bar = 1.0 + 0.2*randn;
            trusted_count = 18 + randi([-1 1]);
            trust_bar = 0.95 + 0.02*randn;

        case 1
            % Open
            sigma_rssi_bar = 5.0 + 0.7*randn;
            sigma_gps_bar  = 2.0 + 0.4*randn;
            snr_bar = 75 + 4*randn;
            plr_bar = 0.02 + 0.005*randn;
            relative_speed_bar = 1.0 + 0.2*randn;
            relative_height_bar = 2.5 + 0.5*randn;
            trusted_count = 15 + randi([-2 2]);
            trust_bar = 0.85 + 0.04*randn;

        case 2
            % Suburban
            sigma_rssi_bar = 20.0 + 2.0*randn;
            sigma_gps_bar  = 10.0 + 1.2*randn;
            snr_bar = 40 + 5*randn;
            plr_bar = 0.08 + 0.015*randn;
            relative_speed_bar = 3.0 + 0.5*randn;
            relative_height_bar = 5.0 + 1.0*randn;
            trusted_count = 10 + randi([-2 2]);
            trust_bar = 0.70 + 0.06*randn;

        case 3
            % DenseUrban
            sigma_rssi_bar = 60.0 + 5.0*randn;
            sigma_gps_bar  = 30.0 + 3.0*randn;
            snr_bar = 15 + 4*randn;
            plr_bar = 0.20 + 0.03*randn;
            relative_speed_bar = 6.0 + 1.0*randn;
            relative_height_bar = 10.0 + 2.0*randn;
            trusted_count = 5 + randi([-2 2]);
            trust_bar = 0.40 + 0.08*randn;
    end

    %% Keep values safe

    sigma_rssi_bar = max(sigma_rssi_bar, 0);
    sigma_gps_bar  = max(sigma_gps_bar, 0);
    snr_bar = max(snr_bar, 0);
    plr_bar = min(max(plr_bar, 0), 1);
    relative_speed_bar = max(relative_speed_bar, 0);
    relative_height_bar = max(relative_height_bar, 0);
    trusted_count = min(max(trusted_count, 0), 20);
    trust_bar = min(max(trust_bar, 0), 1);

    %% Current theta before SAC update

    old_theta = currentTheta;

    obs = [
        sigma_rssi_bar, ...
        sigma_gps_bar, ...
        snr_bar, ...
        plr_bar, ...
        relative_speed_bar, ...
        relative_height_bar, ...
        trusted_count, ...
        trust_bar, ...
        old_theta ...
    ];

    %% ------------------------------------------------------------
    % Call exported SAC actor from Python
    %% ------------------------------------------------------------

    delta_T = sacActorPredictMATLAB(obs, actorFile);

    %% Update dynamic threshold

    new_theta = old_theta + delta_T;
    new_theta = min(max(new_theta, theta_min), theta_max);

    currentTheta = new_theta;

    %% Save logs

    envIdLog(t) = envId;
    envNameLog(t) = envName;

    theta_old_log(t) = old_theta;
    delta_T_log(t) = delta_T;
    theta_new_log(t) = new_theta;

    obsLog(t,:) = obs;

    fprintf("t=%03d | Env=%s | old_theta=%8.4f | delta_T=%8.4f | new_theta=%8.4f\n", ...
        t, envName, old_theta, delta_T, new_theta);
end

%% ============================================================
% Create result table
%% ============================================================

resultTable = table();

resultTable.timeStep = (1:T)';
resultTable.envId = envIdLog;
resultTable.envName = envNameLog;

resultTable.sigma_rssi_bar = obsLog(:,1);
resultTable.sigma_gps_bar = obsLog(:,2);
resultTable.snr_bar = obsLog(:,3);
resultTable.plr_bar = obsLog(:,4);
resultTable.relative_speed_bar = obsLog(:,5);
resultTable.relative_height_bar = obsLog(:,6);
resultTable.trusted_count = obsLog(:,7);
resultTable.trust_bar = obsLog(:,8);

resultTable.theta_old = theta_old_log;
resultTable.delta_T = delta_T_log;
resultTable.theta_new = theta_new_log;

outCsv = fullfile(outDir, "sac_dynamic_threshold_generation_test.csv");
writetable(resultTable, outCsv);

fprintf("\nSaved result table:\n%s\n", outCsv);

%% ============================================================
% Plot 1: Dynamic threshold over time
%% ============================================================

fig1 = figure("Name", "SAC Dynamic Threshold Test", "NumberTitle", "off");
fig1.Position = [100 100 1100 600];

hold on;
grid on;

plot(resultTable.timeStep, resultTable.theta_new, "-o", ...
    "LineWidth", 2.2, ...
    "MarkerSize", 4, ...
    "DisplayName", "SAC Dynamic Threshold");

yline(theta_static, "--", ...
    "Static Threshold = 10", ...
    "LineWidth", 1.8, ...
    "DisplayName", "Static Threshold");

xline(40, ":", "Perfect -> Open", ...
    "LineWidth", 1.4, ...
    "Interpreter", "none");

xline(80, ":", "Open -> Suburban", ...
    "LineWidth", 1.4, ...
    "Interpreter", "none");

xline(120, ":", "Suburban -> DenseUrban", ...
    "LineWidth", 1.4, ...
    "Interpreter", "none");

xlabel("Time Step", "FontSize", 12, "Interpreter", "none");
ylabel("Dynamic Threshold \theta", "FontSize", 12);
title("Exported SAC Actor Test: Dynamic Phase 1 Threshold Generation", ...
    "FontSize", 14, ...
    "Interpreter", "none");

legend("Location", "best", "Interpreter", "none");
set(gca, "FontSize", 11);

outPng1 = fullfile(outDir, "sac_dynamic_threshold_generation.png");
outPdf1 = fullfile(outDir, "sac_dynamic_threshold_generation.pdf");

exportgraphics(fig1, outPng1, "Resolution", 300);
exportgraphics(fig1, outPdf1);

%% ============================================================
% Plot 2: SAC delta_T over time
%% ============================================================

fig2 = figure("Name", "SAC Delta T Test", "NumberTitle", "off");
fig2.Position = [150 150 1100 600];

hold on;
grid on;

plot(resultTable.timeStep, resultTable.delta_T, "-s", ...
    "LineWidth", 2.0, ...
    "MarkerSize", 4, ...
    "DisplayName", "SAC Output delta_T");

yline(0, "--", ...
    "No Change", ...
    "LineWidth", 1.5, ...
    "DisplayName", "No Change");

xline(40, ":", "Perfect -> Open", ...
    "LineWidth", 1.4, ...
    "Interpreter", "none");

xline(80, ":", "Open -> Suburban", ...
    "LineWidth", 1.4, ...
    "Interpreter", "none");

xline(120, ":", "Suburban -> DenseUrban", ...
    "LineWidth", 1.4, ...
    "Interpreter", "none");

xlabel("Time Step", "FontSize", 12, "Interpreter", "none");
ylabel("Threshold Adjustment delta_T", "FontSize", 12, "Interpreter", "none");
title("Exported SAC Actor Output: Threshold Adjustment Over Time", ...
    "FontSize", 14, ...
    "Interpreter", "none");

legend("Location", "best", "Interpreter", "none");
set(gca, "FontSize", 11);

outPng2 = fullfile(outDir, "sac_delta_T_generation.png");
outPdf2 = fullfile(outDir, "sac_delta_T_generation.pdf");

exportgraphics(fig2, outPng2, "Resolution", 300);
exportgraphics(fig2, outPdf2);

%% ============================================================
% Plot 3: Bar plot by environment using final theta in each environment
%% ============================================================

envFinalTheta = zeros(4,1);
envMeanDelta = zeros(4,1);

for e = 0:3
    idx = resultTable.envId == e;
    envFinalTheta(e+1) = resultTable.theta_new(find(idx, 1, "last"));
    envMeanDelta(e+1) = mean(resultTable.delta_T(idx), "omitnan");
end

fig3 = figure("Name", "SAC Threshold by Environment", "NumberTitle", "off");
fig3.Position = [200 200 900 550];

bar([theta_static*ones(4,1), envFinalTheta]);

xticklabels(envNames);
ylabel("Threshold Value", "Interpreter", "none");
title("Static Threshold vs SAC Dynamic Threshold Across Project Environments", ...
    "Interpreter", "none");

legend("Static Threshold", "SAC Dynamic Threshold", ...
    "Location", "best", ...
    "Interpreter", "none");

grid on;
set(gca, "FontSize", 11);

outPng3 = fullfile(outDir, "static_vs_sac_threshold_project_envs.png");
outPdf3 = fullfile(outDir, "static_vs_sac_threshold_project_envs.pdf");

exportgraphics(fig3, outPng3, "Resolution", 300);
exportgraphics(fig3, outPdf3);

%% ============================================================
% Done
%% ============================================================

fprintf("\nSaved plots:\n");
fprintf("%s\n", outPng1);
fprintf("%s\n", outPng2);
fprintf("%s\n", outPng3);

fprintf("\n===== SAC POLICY TEST COMPLETE =====\n");
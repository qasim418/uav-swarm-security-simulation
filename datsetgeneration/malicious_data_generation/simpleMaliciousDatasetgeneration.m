clc; clear; close all;
rng(7);

%% ============================================================
%  FAST UAV DATA GENERATION
%  Random malicious attacker smoke-test version
%  No GUI / no uavScenario visualization
%% ============================================================

%% ================= CONFIG =================
params.N = 20;
T = 120;

SAVE_DATA = true;
VISUALIZE = false;      % keep false for fast generation

theta = 10;             % Static Phase-1 threshold
thetaGeo = theta^2;     % Phase-2 sphere residual tolerance

ENABLE_MALICIOUS = true;
malicious_ratio = 0.10;       % 10% malicious UAVs
attackType = "random";        % smoke test attack type

% Output filenames
ratio_tag = round(malicious_ratio * 100);
detection_filename = sprintf("uav_detection_%s_%d.csv", attackType, ratio_tag);
rl_filename        = sprintf("uav_rl_%s_%d.csv", attackType, ratio_tag);

fprintf("\n===== FAST DATA GENERATION =====\n");
fprintf("Attack type: %s\n", attackType);
fprintf("Malicious ratio: %.2f\n", malicious_ratio);
fprintf("Visualization: %d\n", VISUALIZE);

%% ================= DATASETS =================
data = [];      % detection dataset
rl_data = [];   % RL state dataset

%% ================= ENVIRONMENT + FORMATION =================
envList = 0:3;
envNames = ["Perfect-NoNoise","Open","Suburban","DenseUrban"];

formationList = 0:2;
formationNames = ["Horizontal","Random-Matrix","Circular"];

%% ================= RADIO MODEL =================
Ptx_dBm = 20;
PL_d0 = 40;
d0 = 1;

%% ================= MAIN LOOP =================
for envId = envList
for formationType = formationList

    fprintf("\nRunning Environment: %s | Formation: %s\n", ...
        envNames(envId+1), formationNames(formationType+1));

    %% ===== MALICIOUS CONTROL =====
    if ENABLE_MALICIOUS
        num_malicious = round(params.N * malicious_ratio);
        malicious_ids = randperm(params.N, num_malicious);
    else
        malicious_ids = [];
    end

    fprintf("Malicious UAV IDs: ");
    fprintf("%d ", malicious_ids);
    fprintf("\n");

    %% ===== ENV PARAMETERS =====
    switch envId
        case 0
            % PERFECT / VACUUM ENVIRONMENT
            sigmaGPS = [0 0 0];
            sigmaShadow = 0;
            n = 2;

        case 1
            % OPEN ENVIRONMENT
            sigmaGPS = [1.5 1.5 2.5];
            sigmaShadow = 1.5;
            n = 2.1;

        case 2
            % SUBURBAN ENVIRONMENT
            sigmaGPS = [3 3 5];
            sigmaShadow = 3;
            n = 2.4;

        case 3
            % DENSE URBAN ENVIRONMENT
            sigmaGPS = [5 5 8];
            sigmaShadow = 6;
            n = 2.8;
    end

    %% ===== RANDOM FORMATION OFFSETS =====
    randomOffsets = zeros(params.N,3);
    safeDist = 6;

    for i = 1:params.N
        valid = false;

        while ~valid
            candidate = [randn*12, randn*12, randn*5];
            valid = true;

            for j = 1:i-1
                if norm(candidate - randomOffsets(j,:)) < safeDist
                    valid = false;
                    break;
                end
            end
        end

        randomOffsets(i,:) = candidate;
    end

    randomOffsets(1,:) = [0 0 0];

    %% ===== UAV INIT =====
    posTrue = zeros(params.N,3);

    for i = 1:params.N
        posTrue(i,:) = [(i-1)*5, 0, 30];
    end

    %% ===== TRAJECTORY STORAGE =====
    trajTrue = zeros(params.N,3,T);

    %% ================= TIME LOOP =================
    for t = 1:T

        %% ===== LEADER MOTION =====
        xLead = -120 + mod(t*3,240);

        if xLead > 120
            xLead = 120 - (xLead - 120);
        end

        leader_pos = [xLead, 0, 30];
        posTrue(1,:) = leader_pos;

        %% ===== FORMATION =====
        for i = 2:params.N

            switch formationType

                case 0   % Horizontal
                    dx = 1.2*(i-1);
                    offset = [-(i-1)*6 + dx, ...
                               0, ...
                               5*sin(0.2*t + i*0.4)];

                case 1   % Random-Matrix
                    offset = randomOffsets(i,:);

                case 2   % Circular
                    ang = 2*pi*(i-2)/(params.N-1);
                    offset = [20*cos(ang), ...
                              20*sin(ang), ...
                              5*sin(0.2*t + i*0.4)];
            end

            posTrue(i,:) = leader_pos + offset;
        end

        trajTrue(:,:,t) = posTrue;

        %% ===== COLLISION CHECK =====
        minSep = inf;

        for a = 1:params.N
            for b = a+1:params.N
                dist = norm(posTrue(a,:) - posTrue(b,:));
                minSep = min(minSep, dist);
            end
        end

        if minSep < 4
            warning("Collision risk at t=%d (min dist = %.2f m)", t, minSep);
        end

        %% ===== BENIGN GPS MODEL =====
        posGPS = posTrue + [ ...
            sigmaGPS(1)*randn(params.N,1), ...
            sigmaGPS(2)*randn(params.N,1), ...
            sigmaGPS(3)*randn(params.N,1)];

        %% ============================================================
        %  RANDOM MALICIOUS ATTACK
        %  Malicious UAV broadcasts randomly shifted GPS position.
        %  This should usually be caught by Phase 1.
        %% ============================================================
        if ENABLE_MALICIOUS && attackType == "random"
            for m = malicious_ids
                % Random spoofing offset.
                % Large enough to create GPS/RSSI mismatch.
                spoof_offset = [ ...
                    40*randn, ...
                    40*randn, ...
                    15*randn ...
                ];

                posGPS(m,:) = posGPS(m,:) + spoof_offset;
            end
        end

        %% ============================================================
        %  PHASE 1 + PHASE 2 + RL FEATURE GENERATION
        %% ============================================================

        for receiver = 1:params.N

            trusted_idx = [];           % final trusted after Phase 1 + Phase 2
            phase1_passed_idx = [];     % passed Phase 1 only

            %% ================= RECEIVER-TARGET DETECTION LOOP =================
            for target = 1:params.N

                if receiver == target
                    continue;
                end

                receiver_malicious = ismember(receiver, malicious_ids);
                target_malicious   = ismember(target, malicious_ids);

                %% ================= PHASE 1 =================
                d_true = norm(posTrue(receiver,:) - posTrue(target,:));
                d_gps  = norm(posGPS(receiver,:) - posGPS(target,:));

                PL = PL_d0 + 10*n*log10(max(d_true,d0)/d0);
                RSSI = Ptx_dBm - PL - sigmaShadow*randn();

                d_rssi = d0 * 10^((Ptx_dBm - RSSI - PL_d0)/(10*n));

                delta_d = abs(d_gps - d_rssi);

                phase1_fail = delta_d > theta;

                %% ===== BUILD PHASE-1 PASSED LIST =====
                if ~phase1_fail
                    phase1_passed_idx = [phase1_passed_idx target];
                end

                %% ================= PHASE 2 =================
                phase2_fail = false;
                maxResidual = NaN;
                jury1 = NaN;
                jury2 = NaN;
                jury3 = NaN;

                if ~phase1_fail

                    candidates = setdiff(phase1_passed_idx, [receiver target]);

                    if numel(candidates) >= 3

                        selected = candidates(randperm(numel(candidates),3));

                        jury1 = selected(1);
                        jury2 = selected(2);
                        jury3 = selected(3);

                        verifiers = [receiver jury1 jury2 jury3];
                        claimedPos = posGPS(target,:);

                        residuals = zeros(4,1);

                        for vv = 1:4

                            verifier = verifiers(vv);

                            d_true_v = norm(posTrue(verifier,:) - posTrue(target,:));

                            PL_v = PL_d0 + 10*n*log10(max(d_true_v,d0)/d0);
                            RSSI_v = Ptx_dBm - PL_v - sigmaShadow*randn();

                            d_rssi_v = d0 * 10^((Ptx_dBm - RSSI_v - PL_d0)/(10*n));

                            residuals(vv) = abs( ...
                                norm(claimedPos - posGPS(verifier,:))^2 ...
                                - d_rssi_v^2 );
                        end

                        maxResidual = max(residuals);
                        phase2_fail = maxResidual > thetaGeo;

                    else
                        % Strict version:
                        % Not enough juries means Phase 2 cannot verify.
                        phase2_fail = true;
                    end
                end

                %% ================= FINAL DECISION =================
                final_flag = phase1_fail || phase2_fail;

                %% ================= STORE DETECTION DATA =================
                if SAVE_DATA
                    row = [ ...
                        envId, formationType, t, ...
                        receiver, target, ...
                        d_true, d_gps, d_rssi, delta_d, ...
                        phase1_fail, ...
                        jury1, jury2, jury3, ...
                        maxResidual, phase2_fail, ...
                        final_flag, ...
                        target_malicious, ...
                        receiver_malicious, ...
                        malicious_ratio];

                    data = [data; row];
                end

                %% ================= TRUSTED SET FOR RL =================
                if ~final_flag
                    trusted_idx = [trusted_idx target];
                end

            end

            %% ============================================================
            %  RL FEATURE DATASET: ONE ROW PER RECEIVER PER TIME STEP
            %  Always save RL row, even when trusted_count = 0.
            %% ============================================================

            b_i = length(trusted_idx);

            %% ===== FEATURE SOURCE SELECTION =====
            if b_i > 0
                feature_idx = trusted_idx;
                using_trusted_set = true;
            else
                feature_idx = setdiff(1:params.N, receiver);
                using_trusted_set = false;
            end

            dgps_vals = [];
            drssi_vals = [];
            snr_vals = [];
            dv_vals = [];
            dh_vals = [];
            plr_vals = [];
            trust_vals = [];

            for j = feature_idx

                %% ===== GPS and true distance for RL feature =====
                d_gps_rl  = norm(posGPS(receiver,:) - posGPS(j,:));
                d_true_rl = norm(posTrue(receiver,:) - posTrue(j,:));

                %% ===== RSSI-derived distance =====
                PL_rl = PL_d0 + 10*n*log10(max(d_true_rl,d0)/d0);
                RSSI_rl = Ptx_dBm - PL_rl - sigmaShadow*randn();

                d_rssi_rl = d0 * 10^((Ptx_dBm - RSSI_rl - PL_d0)/(10*n));

                dgps_vals = [dgps_vals d_gps_rl];
                drssi_vals = [drssi_vals d_rssi_rl];

                %% ===== SNR approximation =====
                if sigmaShadow == 0
                    snr_val = 100;
                else
                    noise_power = sigmaShadow^2;
                    snr_val = (10^(RSSI_rl/10)) / noise_power;
                    snr_val = min(snr_val, 100);
                end

                snr_vals = [snr_vals snr_val];

                %% ===== Relative speed =====
                if t > 1
                    v_receiver = squeeze(posTrue(receiver,:) - trajTrue(receiver,:,t-1));
                    v_target   = squeeze(posTrue(j,:) - trajTrue(j,:,t-1));
                    dv = norm(v_receiver - v_target);
                else
                    dv = 0;
                end

                dv_vals = [dv_vals dv];

                %% ===== Relative height =====
                dh = abs(posTrue(receiver,3) - posTrue(j,3));
                dh_vals = [dh_vals dh];

                %% ===== Packet loss ratio approximation =====
                plr = 1 / (1 + exp((RSSI_rl + 70)/5));
                plr_vals = [plr_vals plr];

                %% ===== Trust approximation =====
                delta_rl = abs(d_gps_rl - d_rssi_rl);
                trust = exp(-delta_rl/theta);
                trust_vals = [trust_vals trust];

            end

            %% ===== AGGREGATED RL FEATURES =====
            sigma_gps_bar  = var(dgps_vals);
            sigma_rssi_bar = var(drssi_vals);
            snr_bar        = mean(snr_vals);
            plr_bar        = mean(plr_vals);
            dv_bar         = mean(dv_vals);
            dh_bar         = mean(dh_vals);

            if using_trusted_set
                q_bar = mean(trust_vals);
            else
                q_bar = 0;
            end

            %% ===== STORE RL STATE ALWAYS =====
            if SAVE_DATA
                rl_row = [ ...
                    envId, formationType, t, receiver, ...
                    sigma_rssi_bar, ...
                    sigma_gps_bar, ...
                    snr_bar, ...
                    plr_bar, ...
                    dv_bar, ...
                    dh_bar, ...
                    b_i, ...
                    q_bar, ...
                    theta, ...
                    malicious_ratio];

                rl_data = [rl_data; rl_row];
            end

        end

    end

end
end

%% ================= SAVE DATASETS =================
if SAVE_DATA

    detection_headers = { ...
        'envId','formationType','timeStep', ...
        'receiverId','targetId', ...
        'd_true','d_gps','d_rssi','delta_d', ...
        'phase1_fail', ...
        'jury1','jury2','jury3', ...
        'maxResidual','phase2_fail', ...
        'final_flag', ...
        'actual_target_malicious', ...
        'receiver_malicious', ...
        'malicious_ratio'};

    rl_headers = { ...
        'envId','formationType','timeStep','receiverId', ...
        'sigma_rssi_bar','sigma_gps_bar', ...
        'snr_bar','plr_bar', ...
        'relative_speed_bar','relative_height_bar', ...
        'trusted_count','trust_bar','theta', ...
        'malicious_ratio'};

    detection_table = array2table(data, "VariableNames", detection_headers);
    rl_table = array2table(rl_data, "VariableNames", rl_headers);

    writetable(detection_table, detection_filename);
    writetable(rl_table, rl_filename);

    disp("Datasets saved:");
    disp("1) " + detection_filename);
    disp("2) " + rl_filename);

    fprintf("\nDetection rows: %d\n", height(detection_table));
    fprintf("RL rows: %d\n", height(rl_table));

    fprintf("\nTarget malicious counts:\n");
    disp(groupcounts(detection_table.actual_target_malicious));

    fprintf("\nFinal flag counts:\n");
    disp(groupcounts(detection_table.final_flag));
end

fprintf("\nDONE - Fast random malicious dataset generation complete.\n");
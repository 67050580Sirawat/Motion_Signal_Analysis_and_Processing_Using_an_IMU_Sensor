clc; clear; close all;

%% ========================================================================
% 1. นำเข้าข้อมูลดิบจาก Arduino (ก๊อปปี้ raw_data = [ ... ]; ทั้ง 7 คอลัมน์มาวาง)
% คอลัมน์: [1:t_raw(s), 2:Ax(g), 3:Ay(g), 4:Az(g), 5:Gx(deg/s), 6:Gy(deg/s), 7:Gz(deg/s)]
% =========================================================================
   raw_data = [
];



% แยกตัวแปรสัญญาณดิบ (Asynchronous / Unsampled Raw Data)
t_raw  = raw_data(:, 1);        % เวลาจริงตั้งแต่เริ่มเก็บข้อมูลจุดแรก (วินาที)
Ax_raw = raw_data(:, 2);        % ความเร่งดิบแกน X (g)
Ay_raw = raw_data(:, 3);        % ความเร่งดิบแกน Y (g)
Az_raw = raw_data(:, 4);        % ความเร่งดิบแกน Z (g) - มีแรงโน้มถ่วงโลก ~1g ปนอยู่จริง
Gx_raw = raw_data(:, 5);        % ความเร็วเชิงมุมดิบแกน X (deg/s)
Gy_raw = raw_data(:, 6);        % ความเร็วเชิงมุมดิบแกน Y (deg/s)
Gz_raw = raw_data(:, 7);        % ความเร็วเชิงมุมดิบแกน Z (deg/s)

% คำนวณเวกเตอร์ลัพธ์ดิบ (Signal Vector Magnitude: SVM) ตามกฎฟิสิกส์ 3 มิติ
SVM_A_unsampled = sqrt(Ax_raw.^2 + Ay_raw.^2 + Az_raw.^2);
SVM_G_unsampled = sqrt(Gx_raw.^2 + Gy_raw.^2 + Gz_raw.^2);

%% ========================================================================
% FIGURE 1: พล็อตข้อมูลดิบแท้ๆ จากเซนเซอร์ (ก่อนผ่านการ Sampling และก่อนกรอง)
% เหตุผลทางฟิสิกส์: แสดงแรงปฏิกิริยาตั้งฉากของสนามโน้มถ่วงโลก (~1g) ที่ปนอยู่ในแกนตั้ง
% สัญญาณรบกวนความถี่สูง (Sensor Noise) และความไม่สม่ำเสมอของเวลาอ่านค่า (Sampling Jitter)
% =========================================================================
figure('Name', 'Step 1: Unsampled Raw Sensor Data', 'Color', 'w', 'Position', [40, 100, 950, 680]);

subplot(3, 1, 1);
plot(t_raw, Ax_raw, 'r', t_raw, Ay_raw, 'g', t_raw, Az_raw, 'b', 'LineWidth', 1.0);
title('1.1 ข้อมูลดิบความเร่ง 3 แกน x(t) จาก MPU-6050 (ยังไม่ผ่านการทำ Uniform Sampling และการกรอง)');
xlabel('เวลาจริง t (วินาที)'); ylabel('ความเร่ง (g)');
legend('A_x', 'A_y', 'A_z (สังเกต Offset แรงโน้มถ่วง ~1g)', 'Location', 'northwest');
grid on;

subplot(3, 1, 2);
plot(t_raw, Gx_raw, 'r', t_raw, Gy_raw, 'g', t_raw, Gz_raw, 'b', 'LineWidth', 1.0);
title('1.2 ข้อมูลดิบความเร็วเชิงมุม 3 แกน \omega(t) จาก Gyroscope (มี Gyro Bias และ Noise ปะปน)');
xlabel('เวลาจริง t (วินาที)'); ylabel('ความเร็วเชิงมุม (deg/s)');
legend('G_x (Roll)', 'G_y (Pitch)', 'G_z (Yaw)', 'Location', 'northwest');
grid on;

subplot(3, 1, 3);
dt_raw_ms = diff(t_raw) * 1000; % คำนวณระยะห่างเวลาจริงระหว่างแต่ละจุดข้อมูล (ms)
plot(t_raw(2:end), dt_raw_ms, 'k.-');
title('1.3 พิสูจน์ความไม่คงที่ของคาบเวลาอ่านค่าดิบ (\Delta t ไม่คงที่ -> ต้องนำมาทำ Uniform Sampling ต่อ)');
xlabel('เวลาจริง t (วินาที)'); ylabel('\Delta t ระหว่างจุด (ms)');
grid on;

%% ========================================================================
% 2. ทฤษฎีการชักตัวอย่าง (Uniform Sampling & Nyquist-Shannon Theorem)
% ทฤษฎีที่ใช้: Uniform Periodic Sampling x[n] = x(n*Ts) ภายใต้เกณฑ์ Nyquist (fs >= 2*f_max)
% - การเดิน/วิ่ง/ล้มของมนุษย์ มีความถี่สำคัญไม่เกิน f_max = 15-20 Hz (Nyquist Rate = 40 Hz)
% - การสั่นของการทุบโต๊ะ มีความถี่สำคัญไม่เกิน f_max = 45 Hz (Nyquist Rate = 90 Hz)
% ดังนั้นการเลือก fs = 100 Hz (Nyquist Frequency = 50 Hz) จึงป้องกันการเกิด Aliasing ได้สมบูรณ์
% =========================================================================
fs = 100;                               % ความถี่การชักตัวอย่างตามทฤษฎี Nyquist (100 Hz)
Ts = 1 / fs;                            % คาบการชักตัวอย่างคงที่ Ts = 0.01 วินาที
t_sampled = (0 : Ts : max(t_raw))';     % แกนเวลา Uniform Sampling: t = n*Ts
N = length(t_sampled);                  % จำนวนจุดข้อมูลหลังทำ Sampling

% ทำ Uniform Sampling ลงบนจุดเวลา n*Ts และหักล้างแรงโน้มถ่วงโลก (DC Offset Removal)
SVM_A_sampled = interp1(t_raw, SVM_A_unsampled, t_sampled, 'linear', 'extrap');
SVM_G_sampled = interp1(t_raw, SVM_G_unsampled, t_sampled, 'linear', 'extrap');

% ใช้ช่วง 1 วินาทีแรก (ตอนอยู่นิ่ง) เพื่อหาค่าสนามโน้มถ่วงโลก (~1g) และ Gyro Bias
rest_idx = t_sampled <= 1.0; 
Accel_net_n = SVM_A_sampled - mean(SVM_A_sampled(rest_idx)); % x_A[n] ความเร่งสุทธิ (g)
Gyro_net_n  = SVM_G_sampled - mean(SVM_G_sampled(rest_idx)); % x_G[n] ความเร็วเชิงมุมสุทธิ (deg/s)

%% ========================================================================
% FIGURE 2: พล็อตเปรียบเทียบสัญญาณก่อนและหลังทำ Uniform Sampling (x(t) -> x[n])
% =========================================================================
figure('Name', 'Step 2: Nyquist Uniform Sampling', 'Color', 'w', 'Position', [80, 80, 950, 620]);

subplot(2, 1, 1);
plot(t_raw, SVM_A_unsampled - mean(SVM_A_sampled(rest_idx)), 'Color', [0.75 0.75 0.75], 'LineWidth', 1); hold on;
plot(t_sampled, Accel_net_n, 'b.-', 'MarkerSize', 6, 'LineWidth', 1.0);
title(['2.1 การชักตัวอย่างความเร่งสุทธิ x_A[n] = x_A(nT_s) ที่ f_s = ', num2str(fs), ' Hz (T_s = 0.01 s)']);
xlabel('เวลา t (วินาที)'); ylabel('ความเร่งสุทธิ (g)');
legend('สัญญาณดิบต่อเนื่อง x(t)', 'สัญญาณหลังทำ Uniform Sampling x[n]', 'Location', 'northwest');
grid on;

% ซูมดูช่วงเวลาสั้นๆ (เช่น 0.5 วินาที) เพื่อให้เห็นจุด Discrete Samples x[n] ชัดเจน
subplot(2, 1, 2);
zoom_start = min(2.0, max(t_sampled)/2);
zoom_mask = (t_sampled >= zoom_start) & (t_sampled <= zoom_start + 0.5);
raw_mask  = (t_raw >= zoom_start) & (t_raw <= zoom_start + 0.5);

plot(t_raw(raw_mask), SVM_A_unsampled(raw_mask) - mean(SVM_A_sampled(rest_idx)), '--r', 'LineWidth', 1.2); hold on;
stem(t_sampled(zoom_mask), Accel_net_n(zoom_mask), 'b', 'filled', 'LineWidth', 1.2);
title('2.2 ภาพขยายแสดงการแปลงเป็นลำดับข้อมูลเวลาไม่ต่อเนื่อง (Discrete-Time Sequence x[n]) ตามทฤษฎี Nyquist');
xlabel('เวลา t (วินาที)'); ylabel('ความเร่งสุทธิ x_A[n] (g)');
legend('สัญญาณดิบก่อน Sampling', 'จุดตัวอย่างข้อมูล x[n] ห่างกัน Ts = 10 ms คงที่', 'Location', 'northwest');
grid on;

%% ========================================================================
% 3. ทฤษฎี Convolution & Signal Filtering (FIR Moving Average Low-Pass Filter)
% สมการระบบ LTI: y[n] = x[n] * h[n] = sum_{k=0}^{M-1} x[k] h[n-k]
% เหตุผลทางฟิสิกส์: การเคลื่อนไหวร่างกาย (เดิน 1.5-2.5 Hz) เป็นความถี่ต่ำ แต่แรงสั่นสะเทือนจุลภาค
% และสัญญาณรบกวนไฟฟ้าเป็นความถี่สูง การทำ Convolution กับ h[n] จึงช่วยสกัดเฉพาะการเคลื่อนไหวจริง
% =========================================================================
M = 9;                          % เลือก M = 9 (เลขคี่) เพื่อให้ Симетриกและมี Group Delay = (M-1)/2 = 4 จุดพอดี
h_n = ones(1, M) / M;           % Impulse Response ของตัวกรอง FIR: h[n] = 1/9

% ทำ Discrete-Time Convolution
Accel_filtered_n = conv(Accel_net_n, h_n, 'same');
Gyro_filtered_n  = conv(Gyro_net_n,  h_n, 'same');

%% ========================================================================
% FIGURE 3: พล็อตผลลัพธ์การทำ Convolution Filtering (Time Domain)
% =========================================================================
figure('Name', 'Step 3: Convolution & Signal Filtering', 'Color', 'w', 'Position', [120, 60, 950, 650]);

subplot(2, 1, 1);
plot(t_sampled, Accel_net_n, 'Color', [0.75 0.75 0.75], 'LineWidth', 1.0); hold on;
plot(t_sampled, Accel_filtered_n, 'b', 'LineWidth', 1.6);
title(['3.1 ผลลัพธ์การทำ Convolution: y_A[n] = x_A[n] * h[n] (FIR Low-Pass Filter ขนาด M = ', num2str(M), ')']);
xlabel('เวลา t = nT_s (วินาที)'); ylabel('ความเร่งสุทธิ (g)');
legend('ก่อนกรอง x_A[n] (มี High-Frequency Noise)', 'หลังทำ Convolution y_A[n] (ลดทอน Noise เหลือรูปคลื่นหลัก)', 'Location', 'northwest');
grid on;

subplot(2, 1, 2);
plot(t_sampled, Gyro_net_n, 'Color', [0.85 0.75 0.85], 'LineWidth', 1.0); hold on;
plot(t_sampled, Gyro_filtered_n, 'm', 'LineWidth', 1.6);
title(['3.2 ความเร็วเชิงมุมสุทธิหลังทำ Convolution: y_G[n] = x_G[n] * h[n] (M = ', num2str(M), ')']);
xlabel('เวลา t = nT_s (วินาที)'); ylabel('ความเร็วเชิงมุมสุทธิ (deg/s)');
legend('ก่อนกรอง x_G[n]', 'หลังทำ Convolution y_G[n]', 'Location', 'northwest');
grid on;

%% ========================================================================
% 4. ทฤษฎี Frequency Analysis (Fast Fourier Transform - FFT)
% สมการ DFT: X[k] = sum_{n=0}^{N-1} x[n] * exp(-j*2*pi*k*n/N)
% เหตุผลทางฟิสิกส์และทฤษฎี: แปลงสัญญาณจากโดเมนเวลาไปเป็นโดเมนความถี่ (0 ถึง fs/2 = 50 Hz)
% เพื่อดูความถี่หลักของการเคลื่อนไหว (เช่น ความถี่ก้าวเดิน ~1.5-2.5 Hz) และพิสูจน์ว่าตัวกรอง
% Convolution มีคุณสมบัติเป็น Low-Pass Filter ที่ตัดความถี่สูงทิ้งตามทฤษฎี Convolution Theorem
% =========================================================================
f_axis = (0 : floor(N/2)) * (fs / N); % แกนความถี่ตั้งแต่ 0 Hz ถึง Nyquist Frequency (50 Hz)

% คำนวณ Single-Sided Amplitude Spectrum ของสัญญาณก่อนกรอง X[k]
X_raw_fft = abs(fft(Accel_net_n)) / N;
X_raw_mag = X_raw_fft(1 : floor(N/2)+1);
X_raw_mag(2 : end-1) = 2 * X_raw_mag(2 : end-1); % คูณ 2 เฉพาะความถี่ระหว่าง DC กับ Nyquist

% คำนวณ Single-Sided Amplitude Spectrum ของสัญญาณหลังทำ Convolution Y[k]
Y_filt_fft = abs(fft(Accel_filtered_n)) / N;
Y_filt_mag = Y_filt_fft(1 : floor(N/2)+1);
Y_filt_mag(2 : end-1) = 2 * Y_filt_mag(2 : end-1);

% คำนวณ Frequency Response ของตัวกรอง |H(f)| เพื่อแสดงทฤษฎี Y(f) = X(f)*H(f)
H_freq = abs(fft(h_n, N));
H_freq_half = H_freq(1 : floor(N/2)+1);

%% ========================================================================
% FIGURE 4: พล็อตการวิเคราะห์ความถี่ด้วย FFT และ Frequency Response ของตัวกรอง
% =========================================================================
figure('Name', 'Step 4: Frequency Analysis (FFT)', 'Color', 'w', 'Position', [160, 40, 950, 650]);

subplot(2, 1, 1);
plot(f_axis, X_raw_mag, 'r', 'LineWidth', 1.1); hold on;
plot(f_axis, Y_filt_mag, 'b', 'LineWidth', 1.6);
title('4.1 สเปกตรัมความถี่ (FFT) เปรียบเทียบก่อนและหลังทำ Convolution (0 Hz ถึง f_{Nyquist} = 50 Hz)');
xlabel('ความถี่ f (Hz)'); ylabel('ขนาดแอมพลิจูด |X(f)| (g)');
legend('ก่อนกรอง |X(f)| (มีองค์ประกอบความถี่สูงกระจายตัว)', ...
       'หลังทำ Convolution |Y(f)| (ความถี่สูงถูกกดลง เหลือเฉพาะความถี่หลักของการเคลื่อนไหว)', 'Location', 'northeast');
xlim([0 fs/2]); grid on;

subplot(2, 1, 2);
plot(f_axis, H_freq_half, 'k', 'LineWidth', 1.6);
xline(fs/M, '--r', ['First Null = f_s/M = ', num2str(fs/M, '%.1f'), ' Hz'], 'LineWidth', 1.2);
title(['4.2 ผลตอบสนองความถี่ของตัวกรอง |H(f)| จากทฤษฎี Convolution Theorem: |Y(f)| = |X(f)| \times |H(f)|']);
xlabel('ความถี่ f (Hz)'); ylabel('อัตราขยายขนาด |H(f)|');
legend('Magnitude Response |H(f)| ของ Moving Average Filter (Sinc-like function)', 'จุดความถี่ศูนย์แรก (First Null Bandwidth)', 'Location', 'northeast');
xlim([0 fs/2]); grid on;

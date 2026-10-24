```matlab
clc; clear; close all;

raw_data = [
];

t_raw  = raw_data(:, 1);
Ax_raw = raw_data(:, 2);
Ay_raw = raw_data(:, 3);
Az_raw = raw_data(:, 4);
Gx_raw = raw_data(:, 5);
Gy_raw = raw_data(:, 6);
Gz_raw = raw_data(:, 7);

SVM_A_unsampled = sqrt(Ax_raw.^2 + Ay_raw.^2 + Az_raw.^2);
SVM_G_unsampled = sqrt(Gx_raw.^2 + Gy_raw.^2 + Gz_raw.^2);

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
dt_raw_ms = diff(t_raw) * 1000;
plot(t_raw(2:end), dt_raw_ms, 'k.-');
title('1.3 พิสูจน์ความไม่คงที่ของคาบเวลาอ่านค่าดิบ (\Delta t ไม่คงที่ -> ต้องนำมาทำ Uniform Sampling ต่อ)');
xlabel('เวลาจริง t (วินาที)'); ylabel('\Delta t ระหว่างจุด (ms)');
grid on;

fs = 100;
Ts = 1 / fs;
t_sampled = (0 : Ts : max(t_raw))';
N = length(t_sampled);

SVM_A_sampled = interp1(t_raw, SVM_A_unsampled, t_sampled, 'linear', 'extrap');
SVM_G_sampled = interp1(t_raw, SVM_G_unsampled, t_sampled, 'linear', 'extrap');

rest_idx = t_sampled <= 1.0;
Accel_net_n = SVM_A_sampled - mean(SVM_A_sampled(rest_idx));
Gyro_net_n  = SVM_G_sampled - mean(SVM_G_sampled(rest_idx));

figure('Name', 'Step 2: Nyquist Uniform Sampling', 'Color', 'w', 'Position', [80, 80, 950, 620]);

subplot(2, 1, 1);
plot(t_raw, SVM_A_unsampled - mean(SVM_A_sampled(rest_idx)), 'Color', [0.75 0.75 0.75], 'LineWidth', 1); hold on;
plot(t_sampled, Accel_net_n, 'b.-', 'MarkerSize', 6, 'LineWidth', 1.0);
title(['2.1 การชักตัวอย่างความเร่งสุทธิ x_A[n] = x_A(nT_s) ที่ f_s = ', num2str(fs), ' Hz (T_s = 0.01 s)']);
xlabel('เวลา t (วินาที)'); ylabel('ความเร่งสุทธิ (g)');
legend('สัญญาณดิบต่อเนื่อง x(t)', 'สัญญาณหลังทำ Uniform Sampling x[n]', 'Location', 'northwest');
grid on;

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

M = 9;
h_n = ones(1, M) / M;

Accel_filtered_n = conv(Accel_net_n, h_n, 'same');
Gyro_filtered_n  = conv(Gyro_net_n,  h_n, 'same');

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

f_axis = (0 : floor(N/2)) * (fs / N);

X_raw_fft = abs(fft(Accel_net_n)) / N;
X_raw_mag = X_raw_fft(1 : floor(N/2)+1);
X_raw_mag(2 : end-1) = 2 * X_raw_mag(2 : end-1);

Y_filt_fft = abs(fft(Accel_filtered_n)) / N;
Y_filt_mag = Y_filt_fft(1 : floor(N/2)+1);
Y_filt_mag(2 : end-1) = 2 * Y_filt_mag(2 : end-1);

H_freq = abs(fft(h_n, N));
H_freq_half = H_freq(1 : floor(N/2)+1);

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
```

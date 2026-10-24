#include <Wire.h>

const int MPU_ADDR = 0x68;

// =========================================================================
// เลือกโหมดการแสดงผลและการเก็บข้อมูล
// 1 = ดูกราฟความเร่งดิบ 3 แกน (Ax, Ay, Az) บน Serial Plotter
// 2 = ดูกราฟความเร็วเชิงมุมดิบ 3 แกน (Gx, Gy, Gz) บน Serial Plotter
// 3 = ดูขนาดเวกเตอร์รวมดิบ (Raw SVM Accel vs Raw SVM Gyro) บน Serial Plotter
// 4 = พ่นข้อมูลดิบพร้อมเวลาจริง [t_sec, Ax, Ay, Az, Gx, Gy, Gz] เพื่อนำไปทำ Sampling ใน MATLAB
// =========================================================================
const int TEST_MODE = 1;

// [จุดปรับแก้ตามประเภทการทดลอง #1: ระยะเวลาเก็บข้อมูล]
// - ติดกับโต๊ะแล้วทุบ: แนะนำ 10000 ms (10 วินาที)
// - การเดิน / การวิ่ง: แนะนำ 10000 ถึง 15000 ms เพื่อให้ได้จำนวนก้าวเดินมากพอสำหรับทำ FFT
const unsigned long RECORD_DURATION_MS = 10000; 

unsigned long startTime_us = 0;
bool isStarted = false;
bool isFinished = false;

void setup() {
  // ใช้ Baud Rate สูง (500000) เพื่อให้ส่งข้อมูลดิบออกมาได้เร็วที่สุดโดยไม่คอขวดที่ Serial
  // (อย่าลืมตั้งค่ามุมขวาล่างของ Serial Monitor เป็น 500000 baud ด้วย)
  Serial.begin(500000);
  Wire.begin();
  Wire.setClock(400000); // I2C Fast Mode 400 kHz

  // 1. ปลุก MPU-6050 จากโหมด Sleep
  Wire.beginTransmission(MPU_ADDR);
  Wire.write(0x6B); Wire.write(0x00);
  Wire.endTransmission(true);

  // 2. ปิดวงจรกรองสัญญาณภายในชิป (DLPF = 0x00, Bandwidth = 260 Hz)
  // เพื่อให้ได้สัญญาณดิบ (Raw Unfiltered Signal) ที่มีทั้งสัญญาณจริงและ Noise ครบถ้วน
  Wire.beginTransmission(MPU_ADDR);
  Wire.write(0x1A); Wire.write(0x00);
  Wire.endTransmission(true);

  // =========================================================================
  // 3. [จุดปรับแก้ตามประเภทการทดลอง #2: ตั้งย่านวัด (Full-Scale Range)]
  // =========================================================================
  // - กรณีติดกับโต๊ะแล้วทุบ หรือ เดินปกติ: 
  //   ใช้ +-4g (0x08 -> ตัวหาร 8192.0) และ +-500 deg/s (0x08 -> ตัวหาร 65.5)
  // - กรณีวิ่ง หรือ จำลองการหกล้มกระแทกพื้น (แรงกระแทกอาจเกิน 4g): 
  //   ให้เปลี่ยน 0x08 เป็น 0x10 (+-8g -> เปลี่ยนตัวหารใน loop เป็น 4096.0) 
  //   หรือ 0x18 (+-16g -> เปลี่ยนตัวหารเป็น 2048.0) เพื่อป้องกันกราฟหัวตัด (Clipping)
  Wire.beginTransmission(MPU_ADDR);
  Wire.write(0x1C); Wire.write(0x08); // Accel Range: +-4g (8192 LSB/g)
  Wire.endTransmission(true);

  Wire.beginTransmission(MPU_ADDR);
  Wire.write(0x1B); Wire.write(0x08); // Gyro Range: +-500 deg/s (65.5 LSB/deg/s)
  Wire.endTransmission(true);

  // หมายเหตุ: ตัดส่วนการวนลูปหาค่าเฉลี่ย 100 ครั้ง (Auto-Zero) และ delay(10) ออกทั้งหมด
  // เพื่อให้ข้อมูลที่อ่านได้เป็นค่าดิบแท้ๆ จากเซนเซอร์ (มีแรงโน้มถ่วงโลก 1g และ Offset จริงติดมาด้วย)

  if (TEST_MODE == 4) {
    delay(2000); // รอ 2 วินาทีให้เตรียมตัวก่อนเริ่มเก็บข้อมูลแรก
    Serial.println("raw_data = [");
  }
}

void loop() {
  if (TEST_MODE == 4 && isFinished) return;

  // บันทึกเวลาเริ่มต้น (t = 0.000000 วินาที) ณ จุดข้อมูลแรกสุด
  if (!isStarted) {
    startTime_us = micros();
    isStarted = true;
  }

  // คำนวณเวลาที่ผ่านไปตั้งแต่เริ่มเก็บข้อมูลแรก (หน่วยเป็นวินาที)
  unsigned long elapsed_us = micros() - startTime_us;
  float t_sec = elapsed_us / 1000000.0;

  // อ่านค่าดิบ 14 Bytes จากเรจิสเตอร์ MPU-6050 โดยตรง (ไม่ล็อกคาบเวลา Sampling)
  Wire.beginTransmission(MPU_ADDR);
  Wire.write(0x3B);
  Wire.endTransmission(false);
  Wire.requestFrom(MPU_ADDR, 14, true);

  int16_t rawAx = (Wire.read() << 8) | Wire.read();
  int16_t rawAy = (Wire.read() << 8) | Wire.read();
  int16_t rawAz = (Wire.read() << 8) | Wire.read();
  int16_t rawTemp = (Wire.read() << 8) | Wire.read();
  int16_t rawGx = (Wire.read() << 8) | Wire.read();
  int16_t rawGy = (Wire.read() << 8) | Wire.read();
  int16_t rawGz = (Wire.read() << 8) | Wire.read();

  // แปลงค่า Binary เป็นหน่วยทางฟิสิกส์ (g และ deg/s) โดยไม่หักลบค่าเริ่มต้นใดๆ
  float Ax = rawAx / 8192.0;
  float Ay = rawAy / 8192.0;
  float Az = rawAz / 8192.0;

  float Gx = rawGx / 65.5;
  float Gy = rawGy / 65.5;
  float Gz = rawGz / 65.5;

  // ---------------------------------------------------------------------
  // แสดงผลตามโหมดที่เลือก
  // ---------------------------------------------------------------------
  if (TEST_MODE == 1) {
    // [จุดปรับแก้ตามประเภทการทดลอง #3: สเกลบน Serial Plotter]
    // - ทุบโต๊ะ: Min:-1.5, Max:2.0 | เดิน: Min:-2.0, Max:3.0 | วิ่ง/ล้ม: Min:-4.0, Max:4.0
    Serial.print("Min:-2.0,Max:3.0,");
    Serial.print("Raw_Ax:"); Serial.print(Ax, 3); Serial.print(",");
    Serial.print("Raw_Ay:"); Serial.print(Ay, 3); Serial.print(",");
    Serial.print("Raw_Az:"); Serial.println(Az, 3);
  }
  else if (TEST_MODE == 2) {
    // - ทุบโต๊ะ: Min:-30, Max:30 | เดิน/วิ่ง/ล้ม: Min:-250, Max:250
    Serial.print("Min:-100.0,Max:100.0,");
    Serial.print("Raw_Gx:"); Serial.print(Gx, 2); Serial.print(",");
    Serial.print("Raw_Gy:"); Serial.print(Gy, 2); Serial.print(",");
    Serial.print("Raw_Gz:"); Serial.println(Gz, 2);
  }
  else if (TEST_MODE == 3) {
    float raw_svm_accel = sqrt(Ax*Ax + Ay*Ay + Az*Az);
    float raw_svm_gyro  = sqrt(Gx*Gx + Gy*Gy + Gz*Gz);
    Serial.print("Raw_SVM_Accel(g):"); Serial.print(raw_svm_accel, 3); Serial.print(",");
    Serial.print("Raw_SVM_Gyro(deg/s):"); Serial.println(raw_svm_gyro, 2);
  }
  else if (TEST_MODE == 4) {
    // พ่นข้อมูลดิบ 7 คอลัมน์: [เวลา(s), Ax, Ay, Az, Gx, Gy, Gz]
    Serial.print(t_sec, 6); Serial.print(", ");
    Serial.print(Ax, 4);    Serial.print(", ");
    Serial.print(Ay, 4);    Serial.print(", ");
    Serial.print(Az, 4);    Serial.print(", ");
    Serial.print(Gx, 3);    Serial.print(", ");
    Serial.print(Gy, 3);    Serial.print(", ");
    Serial.print(Gz, 3);    Serial.println(";");

    // หยุดเมื่อครบเวลาที่กำหนด (เช่น 10 วินาที)
    if (elapsed_us >= (RECORD_DURATION_MS * 1000UL)) {
      Serial.println("];");
      isFinished = true;
    }
  }
}

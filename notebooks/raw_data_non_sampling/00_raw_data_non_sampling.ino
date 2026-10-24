#include <Wire.h>

const int MPU_ADDR = 0x68;

const int TEST_MODE = 1;

const unsigned long RECORD_DURATION_MS = 10000; 

unsigned long startTime_us = 0;
bool isStarted = false;
bool isFinished = false;

void setup() {
  Serial.begin(500000);
  Wire.begin();
  Wire.setClock(400000); // I2C Fast Mode 400 kHz


  Wire.beginTransmission(MPU_ADDR);
  Wire.write(0x6B); Wire.write(0x00);
  Wire.endTransmission(true);


  Wire.beginTransmission(MPU_ADDR);
  Wire.write(0x1A); Wire.write(0x00);
  Wire.endTransmission(true);


  Wire.beginTransmission(MPU_ADDR);
  Wire.write(0x1C); Wire.write(0x08); // Accel Range: +-4g (8192 LSB/g)
  Wire.endTransmission(true);

  Wire.beginTransmission(MPU_ADDR);
  Wire.write(0x1B); Wire.write(0x08); // Gyro Range: +-500 deg/s (65.5 LSB/deg/s)
  Wire.endTransmission(true);



  if (TEST_MODE == 4) {
    delay(2000); 
    Serial.println("raw_data = [");
  }
}

void loop() {
  if (TEST_MODE == 4 && isFinished) return;


  if (!isStarted) {
    startTime_us = micros();
    isStarted = true;
  }


  unsigned long elapsed_us = micros() - startTime_us;
  float t_sec = elapsed_us / 1000000.0;


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


  float Ax = rawAx / 8192.0;
  float Ay = rawAy / 8192.0;
  float Az = rawAz / 8192.0;

  float Gx = rawGx / 65.5;
  float Gy = rawGy / 65.5;
  float Gz = rawGz / 65.5;


  if (TEST_MODE == 1) {

    Serial.print("Min:-2.0,Max:3.0,");
    Serial.print("Raw_Ax:"); Serial.print(Ax, 3); Serial.print(",");
    Serial.print("Raw_Ay:"); Serial.print(Ay, 3); Serial.print(",");
    Serial.print("Raw_Az:"); Serial.println(Az, 3);
  }
  else if (TEST_MODE == 2) {

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

    Serial.print(t_sec, 6); Serial.print(", ");
    Serial.print(Ax, 4);    Serial.print(", ");
    Serial.print(Ay, 4);    Serial.print(", ");
    Serial.print(Az, 4);    Serial.print(", ");
    Serial.print(Gx, 3);    Serial.print(", ");
    Serial.print(Gy, 3);    Serial.print(", ");
    Serial.print(Gz, 3);    Serial.println(";");


    if (elapsed_us >= (RECORD_DURATION_MS * 1000UL)) {
      Serial.println("];");
      isFinished = true;
    }
  }
}

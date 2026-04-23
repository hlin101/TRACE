#define X_EN   8
#define X_STEP 9
#define X_DIR  10

#define Y_EN   5
#define Y_STEP 6
#define Y_DIR  7

#define SENSOR_PIN A0

// --- Parameters ---
const int  X_STEP_SIZE   = 160;
const int  Y_STEP_SIZE   = 3200;
const long X_STEPS_TOTAL = 300L * X_STEP_SIZE;
const long Y_STEPS_TOTAL = 15L  * Y_STEP_SIZE;
const int  STEP_DELAY    = 300;
const int  PULSE_WIDTH   = 10;

// --- Calibration ---
const float V_ZERO      = 2.49;
const float MM_PER_V    = 32.26;
const float ADC_REF     = 5.0;
const float MM_PER_STEP = 0.000625;
const float V_SATURATED = 4.95;

void setup() {
  Serial.begin(9600);
  pinMode(X_EN, OUTPUT); pinMode(X_STEP, OUTPUT); pinMode(X_DIR, OUTPUT);
  pinMode(Y_EN, OUTPUT); pinMode(Y_STEP, OUTPUT); pinMode(Y_DIR, OUTPUT);
  enableMotors();
  delay(1000); // sensor stabilise
}

void loop() {
  if (Serial.available() > 0) {
    char cmd = Serial.read();
    if (cmd == 'G') {
      Serial.println("STARTING_SCAN");
      rasterScan();
    }
    if (cmd == 'E') enableMotors();
    if (cmd == 'D') disableMotors();
  }
}

void rasterScan() {
  bool moveForward = true;
  long x_pos = 0;
  long y_pos = 0;

  for (long y = 0; y < Y_STEPS_TOTAL; y += Y_STEP_SIZE) {
    digitalWrite(X_DIR, moveForward ? HIGH : LOW);

    for (long x = 0; x < X_STEPS_TOTAL; x += X_STEP_SIZE) {
      stepMotor(X_STEP, X_STEP_SIZE);

      if (moveForward) x_pos += X_STEP_SIZE;
      else             x_pos -= X_STEP_SIZE;

      delay(5);

      int   adc       = analogRead(SENSOR_PIN);
      float voltage   = (adc / 1023.0) * ADC_REF;
      float x_mm      = x_pos * MM_PER_STEP;
      float y_mm      = y_pos * MM_PER_STEP;

      Serial.print(x_mm, 4); Serial.print(" ");
      Serial.print(y_mm, 4); Serial.print(" ");

      if (voltage >= V_SATURATED) {
        Serial.println("NaN");
      } else {
        float thickness = (voltage - V_ZERO) * MM_PER_V;
        thickness = max(thickness, 0.0);  // clamp negatives to 0
        Serial.println(thickness, 4);
      }
    }

    digitalWrite(Y_DIR, HIGH);
    stepMotor(Y_STEP, Y_STEP_SIZE);
    y_pos += Y_STEP_SIZE;
    moveForward = !moveForward;
  }

  // --- Return to Origin ---
  if (x_pos != 0) {
    digitalWrite(X_DIR, (x_pos > 0) ? LOW : HIGH);
    stepMotor(X_STEP, abs(x_pos));
  }
  digitalWrite(X_EN, HIGH);  // disable X during Y return
  delay(50);
  digitalWrite(Y_DIR, LOW);
  stepMotor(Y_STEP, y_pos);
  digitalWrite(X_EN, LOW);   // re-enable X after

  Serial.println("FINISHED");
}

void stepMotor(int stepPin, long steps) {
  for (long i = 0; i < steps; i++) {
    digitalWrite(stepPin, HIGH);
    delayMicroseconds(PULSE_WIDTH);
    digitalWrite(stepPin, LOW);
    delayMicroseconds(STEP_DELAY);
  }
}

void enableMotors()  { digitalWrite(X_EN, LOW);  digitalWrite(Y_EN, LOW);  }
void disableMotors() { digitalWrite(X_EN, HIGH); digitalWrite(Y_EN, HIGH); }
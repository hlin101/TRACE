// =============================================
// XY Stepper Motor Controller (TOGGLE VERSION)
// =============================================

// --- Pin Definitions ---
#define X_EN   8
#define X_STEP 9
#define X_DIR  10

#define Y_EN   5
#define Y_STEP 6
#define Y_DIR  7

// --- Config ---
int stepDelay = 300;
const int PULSE_WIDTH = 10;

// --- State variables ---
bool xMoving = false;
bool yMoving = false;

bool xDir = HIGH;
bool yDir = HIGH;

// =============================================
void setup() {
  Serial.begin(9600);

  pinMode(X_EN, OUTPUT);
  pinMode(X_STEP, OUTPUT);
  pinMode(X_DIR, OUTPUT);

  pinMode(Y_EN, OUTPUT);
  pinMode(Y_STEP, OUTPUT);
  pinMode(Y_DIR, OUTPUT);

  enableMotors();

  Serial.println("=== TOGGLE CONTROL ===");
  Serial.println("W/S toggle Y axis");
  Serial.println("A/D toggle X axis");
}

// =============================================
void loop() {

  // --- Handle input ---
  if (Serial.available() > 0) {
    char cmd = Serial.read();

    switch (cmd) {
      case 's': case 'S':
        if (yMoving && yDir == HIGH) {
          yMoving = false; // stop
          Serial.println("Y stopped");
        } else {
          yDir = HIGH;
          yMoving = true;
          Serial.println("Y moving UP");
        }
        break;

      case 'w': case 'W':
        if (yMoving && yDir == LOW) {
          yMoving = false;
          Serial.println("Y stopped");
        } else {
          yDir = LOW;
          yMoving = true;
          Serial.println("Y moving DOWN");
        }
        break;

      case 'd': case 'D':
        if (xMoving && xDir == LOW) {
          xMoving = false;
          Serial.println("X stopped");
        } else {
          xDir = LOW;
          xMoving = true;
          Serial.println("X moving LEFT");
        }
        break;

      case 'a': case 'A':
        if (xMoving && xDir == HIGH) {
          xMoving = false;
          Serial.println("X stopped");
        } else {
          xDir = HIGH;
          xMoving = true;
          Serial.println("X moving RIGHT");
        }
        break;

      case 'h': case 'H':
        disableMotors();
        Serial.println("Motors DISABLED");
        break;

      case 'e': case 'E':
        enableMotors();
        Serial.println("Motors ENABLED");
        break;
    }
  }

  // --- Continuous motion ---
  if (xMoving) {
    stepMotor(X_STEP, X_DIR, xDir);
  }

  if (yMoving) {
    stepMotor(Y_STEP, Y_DIR, yDir);
  }
}

// =============================================
void stepMotor(int stepPin, int dirPin, bool direction) {
  digitalWrite(dirPin, direction);
  digitalWrite(stepPin, HIGH);
  delayMicroseconds(PULSE_WIDTH);
  digitalWrite(stepPin, LOW);
  delayMicroseconds(stepDelay);
}

// =============================================
void enableMotors() {
  digitalWrite(X_EN, LOW);
  digitalWrite(Y_EN, LOW);
}

void disableMotors() {
  digitalWrite(X_EN, HIGH);
  digitalWrite(Y_EN, HIGH);
}
// Parameter //////////////////////////////////////////////////////////
#define PWM 5                       // cutter動作用モータのPWM出力
#define A 3                         // モータドライバ Aピン                         
#define B 4                         // モータドライバ Bピン
#define TSW 6                       // Close_cutter_SW:上
#define BSW 7                       // Open_cutter_SW:下
#define OPTICAL 1                   // 光センサ
#define EDF 9                       // EDFのPWM出力

int optical_sensor = 0;             // 光センサの値:Analog
int sensor_threshold = 900;        // 光センサの閾値
int top_sw = 1;                     // TSW(Top_SW)の値を格納する
int bottom_sw = 1;                  // BSW(Bottom_SW)の値を格納する

int InitEDF_PWM = 100;              // EDF起動時のPWM
int EDF_PWM;                        // EDF吸引時のPWM(serialで受信)

uint8_t receive_data;               // Simulinkから受信したデータ
uint8_t mode;                       // 上位3bitはEEのモード番号
uint8_t edf;                        // 下位5bitはEDFのPWMの値(1/10)

uint8_t send_data;                  // Simulinkに送信するデータ
uint8_t flag = 0;                   // EEの状態
uint8_t sensor = 0;                 // 光センサの値

// Function ///////////////////////////////////////////////////////////

void Decryption(){                  // 受信データの複合化
  mode = receive_data >> 5;         // 上位3bitを取り出す
  edf = receive_data & 31;         // 下位5bitを取り出す
}

void Send(){                        // 送信データの作成と送信
  send_data = (flag << 4) + sensor; // 上位4bitがEEの状態，残りがセンサ値
  Serial.write(send_data);
  //Serial.println('a');
}

void setup() {                      // 初期化とPin番号の設定
  pinMode(A, OUTPUT);               // モータドライバ Aピン
  pinMode(B, OUTPUT);               // モータドライバ Bピン
  pinMode(PWM, OUTPUT);             // cutter動作用モータのPWM出力
  pinMode(TSW, INPUT_PULLUP);       // Close_cutter_SW:上
  pinMode(BSW, INPUT_PULLUP);       // Open_cutter_SW:下
  pinMode(OPTICAL, INPUT);          // 光センサ
  pinMode(EDF, OUTPUT);             // EDF用PWM出力

  digitalWrite(A, HIGH);            // モータ停止
  digitalWrite(B, HIGH);

  digitalWrite(A, HIGH);            // cutterを開く
  digitalWrite(B, LOW);
  while(digitalRead(BSW)){          // 下側のスイッチに触れるまで回転
    analogWrite(PWM, 150);
  }
  analogWrite(PWM, 0);

  digitalWrite(A, HIGH);            // モータ停止
  digitalWrite(B, HIGH);

  analogWrite(EDF, InitEDF_PWM);
  delay(3000);

  Serial.begin(115200);
}

void loop() {                       // メインプログラム
  if(Serial.available() > 0){
    flag = 0;
    receive_data = Serial.read();
    optical_sensor = analogRead(OPTICAL);
    sensor = round(optical_sensor / 20) - 41;
    if(sensor < 0){
      sensor = 0;
    }else if(sensor > 15){
      sensor = 15;
    }

    Decryption();
    EDF_PWM = edf * 10;
    
    switch(mode){
      case 0:                       // Wait:cutterが閉じていれば開く
        flag = 0;
        analogWrite(EDF, InitEDF_PWM);
        analogWrite(PWM, 0);
        Send();
        if(digitalRead(BSW)){
          digitalWrite(A, HIGH);
          digitalWrite(B, LOW);
          analogWrite(PWM, 250);
        }else{
          digitalWrite(A, HIGH);
          digitalWrite(B, HIGH);
        }
        break;

      case 1:                       // Suction:EDFによる吸引
        flag = 1;
        analogWrite(EDF, EDF_PWM);
        if(optical_sensor > sensor_threshold){
          flag = 5;
        }
        Send();
        break;

      case 2:                       // Close cutter:光センサで把持確認
        flag = 2;
        analogWrite(EDF, EDF_PWM);
        top_sw = digitalRead(TSW);
        if(top_sw == 0){
          flag = 6;
          digitalWrite(A, HIGH);
          digitalWrite(B, HIGH);
        }else{
          digitalWrite(A, LOW);
          digitalWrite(B, HIGH);
          analogWrite(PWM, 250);
        }
        Send();
        break;

      case 3:                       // Open cutter:光センサで果実の監視
        flag = 3;
        analogWrite(EDF, EDF_PWM);
        bottom_sw = digitalRead(BSW);
        if(optical_sensor > sensor_threshold){
          flag = 8;
        }
        if(bottom_sw == 0){
          flag = 7;
          digitalWrite(A, HIGH);
          digitalWrite(B, HIGH);
        }else{
          digitalWrite(A, HIGH);
          digitalWrite(B, LOW);
//          analogWrite(PWM, 180);
          analogWrite(PWM, 250);
        }
        Send();
        break;

      case 4:                       // Hold fruit:光センサで確認
        analogWrite(EDF, EDF_PWM);
        digitalWrite(A, HIGH);
        digitalWrite(B, HIGH);
        flag = 4;
        /*
        if(optical_sensor > sensor_threshold){
          flag = 4;
        }else{
          analogWrite(EDF, InitEDF_PWM);
          flag = 0;
        }*/
        Send();
        break;
      case 5:                       // For Test:1つ前の状態を維持する
        if(optical_sensor > sensor_threshold){
          flag = 9;
        }else{
          flag = 10;
        }
        Send();
        break;
    }
  }
}

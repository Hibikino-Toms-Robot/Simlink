// Parameter //////////////////////////////////////////////////////////
#define PWM 5                       // cutter動作用モータのPWM出�?
#define A 3                         // モータドライ�? Aピン                         
#define B 4                         // モータドライ�? Bピン
#define TSW 6                       // Close_cutter_SW:�?
#define BSW 7                       // Open_cutter_SW:�?
#define OPTICAL 1                   // 光センサ
#define EDF 9                       // EDFのPWM出�?

int optical_sensor = 0;             // 光センサの値:Analog
int optical_sensor_cali[10];        // 光センサのしきい値のキャリブレーション用
int sensor_threshold = 0;           // 光センサのしきい値の初期化
//int sensor_threshold = 750;        // 2020_1206_1302@greenhouse
//int sensor_threshold = 900;        // 光センサの閾値?��デフォル�?(室�?)?�?900?�?
//int sensor_threshold = 850;        // 2020_1205_1326@Greenhouse
int top_sw = 1;                     // TSW(Top_SW)の値を�?�納す�?
int bottom_sw = 1;                  // BSW(Bottom_SW)の値を�?�納す�?

int InitEDF_PWM = 100;              // EDF起動時のPWM
int EDF_PWM;                        // EDF吸引時のPWM(serialで受信)

uint8_t receive_data;               // Simulinkから受信した�?ータ
uint8_t mode;                       // 上�?3bitはEEのモード番号
uint8_t edf;                        // 下�?5bitはEDFのPWMの値(1/10)

uint8_t send_data;                  // Simulinkに送信する�?ータ
uint8_t flag = 0;                   // EEの状�?
uint8_t sensor = 0;                 // 光センサの値

// Function ///////////////////////////////////////////////////////////

void Decryption(){                  // 受信�?ータの�?合化
  mode = receive_data >> 5;         // 上�?3bitを取り�?��?
  edf = receive_data & 31;         // 下�?5bitを取り�?��?
}

void Send(){                        // 送信�?ータの作�?�と送信
  send_data = (flag << 4) + sensor; // 上�?4bitがEEの状態，残りがセンサ値
  Serial.write(send_data);
  //Serial.println('a');
}

void setup() {                      // 初期化とPin番号の設�?
  pinMode(A, OUTPUT);               // モータドライ�? Aピン
  pinMode(B, OUTPUT);               // モータドライ�? Bピン
  pinMode(PWM, OUTPUT);             // cutter動作用モータのPWM出�?
  pinMode(TSW, INPUT_PULLUP);       // Close_cutter_SW:�?
  pinMode(BSW, INPUT_PULLUP);       // Open_cutter_SW:�?
  pinMode(OPTICAL, INPUT);          // 光センサ
  pinMode(EDF, OUTPUT);             // EDF用PWM出�?

  digitalWrite(A, HIGH);            // モータ停止
  digitalWrite(B, HIGH);

  digitalWrite(A, HIGH);            // cutterを開�?
  digitalWrite(B, LOW);
  while(digitalRead(BSW)){          // 下�?�のスイ�?チに触れるまで回転
    analogWrite(PWM, 30);
  }
  analogWrite(PWM, 0);

  digitalWrite(A, HIGH);            // モータ停止
  digitalWrite(B, HIGH);

  analogWrite(EDF, InitEDF_PWM);
  delay(3000);

  Serial.begin(115200);

  // 光センサから10個のデータ取得
  int cnt = 0;  // カウント変数
  for(cnt = 0 ; cnt < 10 ; cnt++){
    optical_sensor_cali[cnt] = analogRead(OPTICAL); //光センサの値取得
  }
  // 光センサ10のデータの平均値
  int optical_sensor_sum = 0; //10個の光センサデータの合計変数の初期化
  double optical_sensor_mean = 0; //光センサの平均値変数の初期化
  cnt = 0;
  for(cnt = 0 ; cnt < 10 ; cnt++){
    optical_sensor_sum += optical_sensor_cali[cnt];  //10個の光センサデータの合計
  }
  optical_sensor_mean = (double)optical_sensor_sum / (double)(cnt + 1); // 光センサの平均値
  double t = 0; //偏差変数の初期化
  double optical_sensor_std = 0; //標準偏差変数の初期化
  cnt = 0;
  for(cnt = 0 ; cnt < 10 ; cnt++){
    t += (double)optical_sensor_cali[cnt] - (double)optical_sensor_mean; //偏差
  }
  optical_sensor_std = sqrt(t / (double)(cnt + 1)); //標準偏差
  if(optical_sensor_std > 100){ //分散が大きすぎる場合
    sensor_threshold = 900;
  }
  else{ //分散が許容範囲である場合
    sensor_threshold = (int)optical_sensor_mean + 50; //平均値+50をしきい値とする
  }  
}

void loop() {                       // メインプログラム
  if(Serial.available() > 0){
    flag = 0;
    receive_data = Serial.read();
    optical_sensor = analogRead(OPTICAL);
    //sensor = round(optical_sensor / 20) - 41;
    sensor = round((optical_sensor-700)/10);
    if(sensor < 0){
      sensor = 0;
    }else if(sensor > 15){
      sensor = 15;
    }

    Decryption();
    EDF_PWM = edf * 10;
    
    switch(mode){
      case 0:                       // Wait:cutterが閉じて�?れ�?�開く
        flag = 0;
        analogWrite(EDF, InitEDF_PWM);
        analogWrite(PWM, 0);
        Send();
        if(digitalRead(BSW)){
          digitalWrite(A, HIGH);
          digitalWrite(B, LOW);
          analogWrite(PWM, 50);
        }else{
          digitalWrite(A, HIGH);
          digitalWrite(B, HIGH);
        }
        break;

      case 1:                       // Suction:EDFによる吸�?
        flag = 1;
        analogWrite(EDF, EDF_PWM);
        if(optical_sensor > sensor_threshold){
          flag = 5;
        }
        Send();
        break;

      case 2:                       // Close cutter:光センサで把持確�?
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
          analogWrite(PWM, 50);
        }
        Send();
        break;

      case 3:                       // Open cutter:光センサで果実�?�監�?
        flag = 3;
        analogWrite(EDF, InitEDF_PWM);
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
          analogWrite(PWM, 36);
        }
        Send();
        break;

      case 4:                       // Hold fruit:光センサで確�?
        analogWrite(EDF, EDF_PWM);
        digitalWrite(A, HIGH);
        digitalWrite(B, HIGH);
        if(optical_sensor > sensor_threshold){
          flag = 4;
        }else{
          analogWrite(EDF, InitEDF_PWM);
          flag = 0;
        }
        Send();
        break;
      case 5:                       // For Test:1つ前�?�状態を維持す�?
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

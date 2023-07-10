//Pin番号定義 CO
#define start 11
#define runbrake 10
#define cwccw 9
#define pwm 5
#define INT 8
#define AlarmReset 7
#define Speed 1

//受信データ
int8_t receive_data;        //受信データ(生データ):Simulinkからの情報

//送信データ
uint8_t send_data;          //送信データ(生データ):8bit目がflag，1～7bit目に距離
uint8_t distance_cm = 0;    //送信データ(距離)(0～127)[cm]
uint8_t flag = 0;           //送信データ(フラグ)

//パラメータ
float r = 0.0250;           //車輪半径[m]
float rot = 0.0000;         //車輪の回転数[rot]
double distance_m = 0;      //移動距離[m]
int cart_direction = 1;     //現在の移動方向(左:1 右:-1 エラー:0)
int prev_direction = 1;     //1サイクル前の移動方向(左:1 右:-1 エラー:0)
volatile int pulse = 0;     //エンコーダで数えたパルス数

//初期化
void setup() {
  pinMode(start, OUTPUT);     //H:START L:STOP
  pinMode(runbrake, OUTPUT);  //H:RUN L:BREAK(Instant stop)
  pinMode(cwccw, OUTPUT);     //H:CW(Right) L:CCW(Left)
  pinMode(INT, OUTPUT);       //Don't use. Always LOW.
  pinMode(AlarmReset, OUTPUT);//Don't use. Always LOW.
  pinMode(pwm, OUTPUT);       //This pin is Analog pin. Output 0～5V.
//  pinMode(13, OUTPUT);        //Test用

  digitalWrite(INT, HIGH);
  digitalWrite(AlarmReset, HIGH);

  //最初はモータをストップさせておく
  digitalWrite(start, HIGH);
  digitalWrite(runbrake, HIGH);

  Serial.begin(115200);

  //割り込み処理定義
  attachInterrupt(Speed, RecognizeRotation, FALLING);
}

//パルスの立下り数を検出
void RecognizeRotation(void){
  pulse++;
}

//データ送信プログラム
void Send_Data(void){
  send_data = ( flag << 7) + distance_cm;

  //Simulinkに[cm]単位で距離を送信
//  delay(500);
  Serial.write(send_data);
  //Serial.write(30);
  //Serial.println(1);
  
}

//移動距離の計算
void Calculate_distance(void){
  rot = pulse / 450.0;  //900 = 30(モータの1回転あたりのパルス数) * 15(減速比)
  distance_m = rot * (2.0 * 3.1416 * r);
  distance_cm = distance_m * 100;
  if(distance_cm >= 0 && distance_cm <=100){
    flag = 0;
  }else if(distance_cm > 100){
    pulse = 0;
    flag = 1;
    distance_cm -= 100;
  }
}

//モータ正回転
void Forward_motor(int vel){
  //運転
  digitalWrite(start,LOW);     //New circuit
  digitalWrite(runbrake,LOW);  //New circuit
  //正転
  digitalWrite(cwccw,HIGH);     //New circuit
  //速度
  analogWrite(pwm, abs(vel));
}

//モータ逆回転
void Reverse_motor(int vel){
  //運転
  digitalWrite(start,LOW);     //New circuit
  digitalWrite(runbrake,LOW);  //New circuit
  //逆転
  digitalWrite(cwccw,LOW);      //New circuit
  //速度
  analogWrite(pwm, abs(vel));
}

//モータ停止
void Stop_motor(void){
  //停止
  digitalWrite(start,HIGH);      //New circuit
  digitalWrite(runbrake,HIGH);   //New circuit
  //速度
  analogWrite(pwm, 0);
}

//モータ瞬時停止
void InstantStop_motor(void){
  //瞬時停止
  digitalWrite(runbrake,HIGH); //New circuit
  digitalWrite(start,HIGH); //New circuit
  //速度
  analogWrite(pwm, 0);
}

/* 
 * 停止は減速の立下りが加速の立上りとほぼ同じ挙動をする
 * そのため、速度-時間曲線は等脚台形になる(ハズ)
 * それに対し瞬時停止はほぼ90度の角度で立下る
 * 挙動についてはモータの取扱説明書または引継資料を参照のこと
 */

//速度制御
void Control_Motor(void){
  //正転
  if( receive_data<0 && receive_data>=-128 ){
    Forward_motor(receive_data);
    cart_direction = 1;         //左移動
    if(prev_direction == -1){   //方向が変わるとリセット
      pulse = 0;
    }
    Calculate_distance();
  }
  //逆転
  else if( receive_data>0 && receive_data<=127){
    Reverse_motor(receive_data);
    cart_direction = -1;        //右移動
    if(prev_direction == 1){   //方向が変わるとリセット
      pulse = 0;
    }
    Calculate_distance();
  }
  //-128<=receive_data<=127以外の値を受信すると、Stop
  else{
    Stop_motor();
    Calculate_distance();
    //★ひとつ前で停止した時までの距離を格納
  }
}

//メインプログラム
void loop() {
//  if(Serial.available() > 0)
  if(Serial.available())
  {
    prev_direction = cart_direction;
    receive_data = Serial.read();
    Control_Motor();
    Send_Data();



  }
//  Reverse_motor(20);
}

/*
 * 
 * ポート番号13
 * 
 */

#include <Stepper.h>

const int cwA=3;
const int cwB=2;
const int ccwA=6;
const int ccwB=5;

const int sw_d=7;
//const int sensor=0;

/* stepsPerRevolution:モータの1回転あたりのステップ数(実験的に調整)
 * これによってsetSpeedのrpmが決まる*/
const int stepsPerRevolution=800;
Stepper myStepperCW(stepsPerRevolution,cwA,cwB);
Stepper myStepperCCW(stepsPerRevolution,ccwA,ccwB);

int target;
int preLocation;//絶対座標
uint16_t targetStep;
int targetStep_sub;
int cwSpeed=580;//モータ回転速度[rpm]
int initialSpeed=200;//モータ回転速度[rpm]、初期速度

char dat[32];   // 格納用文字列
uint8_t count = 0;  // 文字数のカウンタ
char state = 'a'; // 状態確認用
//int SensorVal = 0;
//int preSensorVal = 0;
//int sensorCount = 0;
//int sensorCountTH = 200;

void setup() {
  pinMode(sw_d, INPUT);
  
  pinMode(cwA, OUTPUT);
  pinMode(cwB, OUTPUT);
  pinMode(ccwA, OUTPUT);
  pinMode(ccwB, OUTPUT);
  Serial.begin(115200);
}

int Conversion(int num1, int num2, int num3){
  // 目標位置計算
  // 百の位
  int Num1 = num1 - '0';      // char型をint型に変換
  if (Num1 > 0 && Num1 <10){
    Num1 = Num1*100;          
  } else Num1 = 0;
  
  // 十の位
  int Num2 = num2 - '0';      
  if (Num2 > 0 && Num2 < 10){
    Num2 = Num2*10;           
  } else Num2 = 0;
  int Num3 = num3 - '0'; 

  // 一の位
  if (Num3 > 0 && Num3 < 10){
    Num3 = Num3*1;            
  } else Num3 = 0;
  int Num = Num1 + Num2 + Num3; // 合計

  return Num;
}

int sendPulse(int target){
  myStepperCW.setSpeed(cwSpeed);
  myStepperCCW.setSpeed(cwSpeed);
  target = target;
  if(preLocation>target){
    targetStep=(preLocation-target)*80;
    targetStep_sub=targetStep-32000;
    if(targetStep_sub>0){
      myStepperCW.step(32000);
      myStepperCW.step(targetStep_sub);
    }
    else{
      myStepperCW.step(targetStep);
    }
    preLocation=target;
  }

  else if(preLocation<target){
    targetStep=(target-preLocation)*80;
    targetStep_sub=targetStep-32000;
    if(targetStep_sub>0){
      myStepperCCW.step(32000);
      myStepperCCW.step(targetStep_sub);
    }
    else{
      myStepperCCW.step(targetStep);
    }
    preLocation=target;
  }
  else{
    preLocation=target;
  }
}

void Initialization(int target){
  myStepperCW.setSpeed(initialSpeed);
  myStepperCCW.setSpeed(initialSpeed);



  while(digitalRead(sw_d)==HIGH){
    myStepperCW.step(200);
    delay(5);
  }
  
  preLocation=0;
  state = 'a';
  Serial.println(state);

  /*
  while (digitalRead(sw_d) == HIGH) {
    delay(500);  
    sendPulse(target);
    
  }
  */

  delay(500);  
  sendPulse(target);


  
  state = 'b';
  Serial.println(state);
}

void loop() {
  if(Serial.available()){
    dat[count] = Serial.read();
    if (dat[count] == ',') {  // 文字数が既定の個数を超えた場合、又は終了文字を受信した場合
      // H:Header
      if (dat[0] == 'H'){
        int target = Conversion(dat[2], dat[3], dat[4]);
        // I:Initialize
        if (dat[1] == 'I'){
          state = 'c';
          Serial.println(state);
          Initialization(target);
        }
        // Target position
        else if (dat[1] == 'T'){
          state = 'd';
          Serial.println(state);
          sendPulse(target);
          state = 'e';
          Serial.println(state);
        }
        else if (dat[1] == 'J'){
          myStepperCW.setSpeed(initialSpeed);
          myStepperCCW.setSpeed(initialSpeed);
          if (dat[2] == 'P'){
            state = 'p';
            Serial.println(state);
            //dat[count] = Serial.read();
            //while(dat[2] == 'P'){
              myStepperCW.step(500);
            //}
          }else if (dat[2] == 'M'){
            state = 'm';
            Serial.println(state);
            //dat[count] = Serial.read();
            //while(dat[2] == 'M'){
              myStepperCCW.step(500);
            //}
          } 
        }
      }
      count = 0;                           // 文字カウンタをリセット
    } else {
      count++;                              // 文字カウンタに 1 加算
    }
  }
}

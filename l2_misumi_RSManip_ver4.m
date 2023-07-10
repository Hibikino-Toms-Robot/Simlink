function l2_misumi_RSManip_ver4(block)

%%
% 作成者：D1藤永拓矢
% 作成日：2018年12月2日

% Help for Writing Level-2 M-File S-Functions:
%   web([docroot '/toolbox/simulink/sfg/f7-67622.html']

%   Copyright 2011 The MathWorks, Inc.

% define instance variables
mySerial = [];

manip.mode = 0;
manip.servo_state = 0; % Servo state
manip.origin_state = 0; % Origin state
manip.moved_state = 0; % Move state
manip.chkNum = 0; % Check the Option Number
manip.judeg = 0; % Judeg whether stop or not
manip.targetPos = 0;
manip.input = 0;
manip.output = 0;
manip.nextFlag = 0;
manip.local_count = 0;

manip.a = '';

setup(block);

%% Set the block paremeters

    function setup(block)
        % Register the number of ports.
        block.NumInputPorts  = 2; % Action flag, Target position, Jog
        block.NumOutputPorts = 2; % Current state, Current position
        
        % Set up the states
        block.NumContStates = 0;
        block.NumDworks = 0;
        
        % Register the parameters.
        block.NumDialogPrms     = 3; % COM port, Init position, Speed
        block.DialogPrmsTunable = {'Nontunable', 'Nontunable', 'Nontunable'};
        
        % Setup functional port properties to dynamically inherited
        block.SetPreCompInpPortInfoToDynamic;
        block.SetPreCompOutPortInfoToDynamic;
        
        % Calibration port setting
        block.InputPort(1).Complexity        = 'Inherited';
        block.InputPort(1).DataTypeId        = -1;
        block.InputPort(1).SamplingMode      = 'Sample';
        block.InputPort(1).DimensionsMode    = 'Fixed';
        block.InputPort(1).DirectFeedthrough = true; % 入力を出力関数で直接利用する
        
        % end-effector port setting
        block.InputPort(2).Complexity        = 'Inherited';
        block.InputPort(2).DataTypeId        = 0;
        block.InputPort(2).SamplingMode      = 'Sample';
        block.InputPort(2).DimensionsMode    = 'Fixed';
        block.InputPort(2).DirectFeedthrough = true; % 入力を出力関数で直接利用する
        
        % Register the properties of the output port
        block.OutputPort(1).DataTypeId = 0; % 0 for 'double',
        block.OutputPort(1).DimensionsMode = 'Fixed';
        block.OutputPort(1).SamplingMode   = 'Sample';
        % Register the properties of the output port
        block.OutputPort(2).DataTypeId = 0; % 0 for 'double',
        block.OutputPort(2).DimensionsMode = 'Fixed';
        block.OutputPort(2).SamplingMode   = 'Sample';
        
        
        % Block is fixed in minor time step, i.e., it is only executed on major
        % time steps. With a fixed-step solver, the block runs at the fastest
        % discrete rate.
        % block.SampleTimes = [-1 0];
        block.SampleTimes = [0 1];
        
        block.SetAccelRunOnTLC(false); % run block in interpreted mode even w/ Acceleration
        block.SimStateCompliance = 'DefaultSimState';
        
        block.InputPort(1).Dimensions = 1;
        block.InputPort(2).Dimensions = 1;
        
        block.OutputPort(1).Dimensions = 1;
        block.OutputPort(2).Dimensions = 1;
        
        % If the creation of a new variable is requested, (i.e. no
        % previously instantiated workspace arduino variable is used)
        % then the ArduinoIO block uses the Start method to initize the
        % arduino connection before the variable is actually accessed
        
        block.RegBlockMethod('CheckParameters', @CheckPrms); % called during update diagram
        block.RegBlockMethod('Start', @Start); % called first
        block.RegBlockMethod('Outputs', @Output); % called first in sim loop
        % block.RegBlockMethod('initizeConditions', @InitConditions); % called second
        block.RegBlockMethod('Terminate', @Terminate);
    end

%% Chek the NumDialogPrms

    function CheckPrms(block)
        try
            validateattributes(block.DialogPrm(1).Data, {'char'}, {'nonempty'}); % Serial port
            validateattributes(block.DialogPrm(2).Data, {'double'}, {'nonempty'}); % Init position
            validateattributes(block.DialogPrm(3).Data, {'double'}, {'nonempty'}); % Speed
        catch me
            error('ComNum or InitPos Error');
        end
    end

%%
    function Start(block)

       %% Create the serial object
        % Check the Manual of controller (p.B-2)
        % BaudRate: 38400, Data bits: 8, Parity: odd, StopBits: 1, Flow control: none
        % StartCode: @, Terminal: c/r l/f
        if ~isempty(block.DialogPrm(1).Data)
            mySerial = serial(block.DialogPrm(1).data, ...
                'BaudRate', 38400, ...
                'DataBits', 8,...
                'Parity', 'odd',...
                'StopBits', 1,...
                'FlowControl', 'none');
                % 要確認
                % 'InputBufferSize', 1024*10, 
                % When the port avaailable, 
                % Serial Recieve CollbackFcn is done.
                set(mySerial, 'BytesAvailableFcn' ,@SerialRcv);
        end
        
        try
            fopen(mySerial);                
        catch me
            error(['Serial Port ', block.DialogPrm(1).data,' could not open!']);
        end
        
       %% Change the Servo state
        manip.mode = 1;
        fwrite(mySerial,'@SRVO1,', 'char'); % サーボON指令
%         disp('!!-----ServoON Start-----!!')
        while ~manip.servo_state
            fwrite(mySerial,'@?OPT1,', 'char'); % オプション情報（状態）の読み出し
            if manip.chkNum == 2560 || manip.chkNum == 2048
                if manip.servo_state == 0
                    manip.servo_state = 1;
                end
            % サーボ状態がすでにONの場合の応答番号：2056、2508、2568、2570
            elseif manip.chkNum == 2056 || manip.chkNum == 2058 || manip.chkNum == 2568 || manip.chkNum == 2570
                break;
            end
        end
        disp('!!-----ServoON Finish-----!!')
       %% Origin registration
        manip.mode = 2;
%         fwrite(mySerial,'@ORG,', 'char'); % 原点回帰
% %         disp('!!-----Origin registration Start-----!!')
%         while ~manip.origin_state
%             fwrite(mySerial,'@?OPT1,', 'char'); % オプション情報（状態）の読み出し
% %             disp('!!-----Origin registration Doing-----!!')
%             % 原点回帰完了の場合の応答番号：2584
%             if manip.chkNum == 2584
%                 if manip.origin_state == 0
%                     manip.origin_state = 1;
%                 end
%             % 原点回帰完了がすでに完了の場合の応答番号：2508、2568
%             elseif manip.chkNum == 2058 || manip.chkNum == 2568
%                 break;
%             end
%         end
%         disp('!!-----Origin registration Finish-----!!')
       %% Move the Init position
        manip.mode = 3;
        % 初期位置移動
        initPos = num2str(block.DialogPrm(2).Data); % 初期位置取得
        speed = num2str(block.DialogPrm(3).Data); % 速度取得
        %fwrite(mySerial,strcat('@S1=', num2str(speed), ','), 'char'); % 速度指令
        fwrite(mySerial,strcat('@START1#P', num2str(initPos), '00,'), 'char'); % 初期位置へ移動指令
        while ~manip.moved_state
            fwrite(mySerial,'@?OPT1,', 'char'); % オプション情報（状態）の読み出し
            % 移動完了の場合の応答番号：2570
            if manip.chkNum == 2570
                if manip.moved_state == 0
                    manip.moved_state = 1;
                end 
            % 初期位置指令が遅れなかった場合、指令を再送信
            % 2584、2056：サーボON、原点回帰完了
            elseif manip.chkNum == 2584 || manip.chkNum == 2072
%                disp('check3')
                fwrite(mySerial,strcat('@S1=', num2str(speed), ','), 'char'); % Speed
                fwrite(mySerial,strcat('@START1#P', num2str(initPos), '00,'), 'char'); % initPosition
            end
%            disp(manip.chkNum)
        end
%         disp('!!-----Init position Finish-----!!')      
        manip.moved_state = 0;
    end

%%
    function Output(block)
        % 位置確認
        if manip.judeg == 1
            manip.input = block.InputPort(2).Data;
            manip.mode = 5;
            fwrite(mySerial,'@?P1,', 'char'); % 現在位置情報の読み出し
            if manip.targetPos
                manip.judeg = 0;
            % 0位置のとき
            elseif strcmp(num2str(manip.output), 'NaN') == 1
                manip.judeg = 0;
                manip.moved_state = 1;
            end
        % オプション情報確認
        elseif manip.targetPos == 1
            manip.mode = 6;
            fwrite(mySerial,'@?OPT1,,', 'char'); % オプションの読み出し
%            disp(manip.chkNum)
            if manip.chkNum == 2344
                manip.nextFlag = 1;
            elseif manip.nextFlag == 1 && manip.chkNum == 2346
                manip.nextFlag = 2;
            elseif manip.nextFlag == 2 && manip.chkNum == 2570
                manip.moved_state = 1;
                manip.targetPos = 0;
                manip.nextFlag = 0;
            elseif manip.local_count > 25
                manip.moved_state = 1;
                manip.targetPos = 0;
                manip.nextFlag = 0;
            else % manip.chkNum == 2570
                manip.local_count = manip.local_count + 1;
            end
        % 目標指令    
        elseif block.InputPort(1).Data == 1 && manip.moved_state == 0
            manip.mode = 4;
            fwrite(mySerial,strcat('@START1#P', num2str(block.InputPort(2).Data), '00,'), 'char'); % targetPosition 
        % 目標値へ到達
        elseif block.InputPort(1).Data == 1 && manip.moved_state == 1
            block.OutputPort(1).Data = 1;        
        % 待機
        else
            manip.mode = 7;
            manip.moved_state = 0;
            block.OutputPort(1).Data = 0;
        end        
    end

%%
    function Terminate(block)
        
%         if mySerial.BytesAvailable > 0
%             fread(mySerial, mySerial.BytesAvailable, 'char');
%         end
        % 停止
        fwrite(mySerial,'@STOP.1,', 'char');
        % サーボOFF
        fwrite(mySerial,'@SRVO0,', 'char');
        
        fclose(mySerial);
        delete(mySerial);

    end

%%
    function SerialRcv(obj,event)
        % SerialRcv内で入出力の処理、マニピュレータの制御はできない。
        
        if mySerial.BytesAvailable == 0
            return;
        end
        
        switch manip.mode
            % Start
            case 1 % サーボON
%                 disp('ServoON')
                checkOption();
            case 2 % 原点回帰
%                 disp('Origin Registration')
                checkOption();
            case 3 % 初期位置移動
%                 disp('Initialize')
                checkOption();

            % Output
            case 4 % 目標値指令
%                disp('TargetPos')
                manip.judeg = 1;
            case 5 % 移動情報完了判定
%                disp('Move check position')
                checkPosition()                
            case 6 % 移動情報完了判定
%                disp('Move check option')
                checkOption();
%                disp(manip.targetPos)
            case 7 % 目標値待機
%                disp('Wait')  
            otherwise
%                disp('other')
        end
        
        function checkOption() 
            buf10 = fscanf(mySerial); % オプション情報受信
            if buf10 > 4
                checkResponce = buf10(1:3); %受信内容の確認
                checkLength = length(buf10); %文字列の長さ
                startlm = regexp(buf10,'=');
                % 応答がオプション情報('OPT')、かつ、文字列長が15('OPT1.1=65535')より小さい
                if strcmp(checkResponce, 'OPT') == 1 && checkLength < 15
                    manip.chkNum = str2double(buf10(startlm+1:checkLength));
                    return;
                else
                    return;
                end
            end
        end
        
        function checkPosition() 
            buf = fscanf(mySerial); % オプション情報受信
            if buf > 4
                checkResponce1 = buf(1); %受信内容の確認
                checkLength1 = length(buf); %文字列の長さ
                % 位置情報('P')、かつ、文字列長が12('P1.1=20000')より小さい
                if strcmp(checkResponce1, 'P') == 1 && checkLength1 < 13
                    startlm1 = regexp(buf,'=');
                    checkNum1 = str2double(buf(startlm1+1:checkLength1-4));
                    manip.output = checkNum1;
                    % 移動完了の場合
                    if checkNum1 == manip.input
                        manip.targetPos = 1;
                    end
                end
            end
        end
        
        % SerialRcv内にblock.InputPort/block.OutputPortを入れてはいけない。
        
        % データを非同期で読み取るときにのみ BytesAvailable を使用
%         if mySerial.BytesAvailable == 0
%             return;
%         end
        
%         fwrite(mySerial,'@?P1,', 'char'); % 現在位置情報の読み出し
%         buf = fscanf(mySerial); % オプション情報受信
%         checkResponce1 = buf(1); %受信内容の確認
%         checkLength1 = length(buf); %文字列の長さ
%         
%         manip.a = checkLength1;
%         
%         % 位置情報('P')、かつ、文字列長が12('P1.1=20000')より小さい
%         if strcmp(checkResponce1, 'P') == 1 && checkLength1 < 13
%             startlm1 = regexp(buf,'=');
%             checkNum1 = str2double(buf(startlm1+1:checkLength1-4));
%             manip.output_pos = checkNum1;
            
            % 移動完了の場合
%             if checkNum1 == num2str(block.DialogPrm(2).Data)
%                 % "移動中"オプションの読み出し
%                 fwrite(mySerial,'@?OPT1,,', 'char'); % 現在位置情報の読み出し
%                 buf = fscanf(mySerial); % dummy buffer
%                 buf10 = fscanf(mySerial); % オプション情報受信
%                 buf = fscanf(mySerial); % % dummy buffer
% %                     disp(buf10)
%                 checkLength2 = length(buf10); %文字列の長さ
%                 % buf10の文字列の長さ確認
%                 % 必ずしも'OPT1.1=65535'であるとは限らないので
%                 if checkLength2 > 4
%                     checkResponce2 = buf10(1:3); %受信内容の確認
%                     % オプショ情報('O')、かつ、文字列長が11('OPTB5.1=1')より小さい
%                     if strcmp(checkResponce2, 'OPT') == 1 && checkLength1 < 15
%                         startlm2 = regexp(buf10,'=');
%                         checkNum2 = str2double(buf10(startlm2+1:checkLength2));
%                         disp('chk2')
%                         disp(checkNum2)
%                         % 目標位置移動完了：2570、2346
%                         if checkNum2 == 2570 || checkNum2 == 2346
%                             manip.moved_state = 1;
%                             disp('chk3')
%                         end
%                     end                        
%                 end
%             else
%                 manip.moved_state = 0;
% %                     disp('chk4')
% %             else
% %                 fwrite(mySerial,strcat('@START1#P', targetPos, '00,'), 'char'); % targetPosition
%             end
%         end    
    end

end
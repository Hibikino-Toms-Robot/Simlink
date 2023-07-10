function l2_misumi_RSManip_ver4(block)

%%
% �쐬�ҁFD1���i���
% �쐬���F2018�N12��2��

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
        block.InputPort(1).DirectFeedthrough = true; % ���͂��o�͊֐��Œ��ڗ��p����
        
        % end-effector port setting
        block.InputPort(2).Complexity        = 'Inherited';
        block.InputPort(2).DataTypeId        = 0;
        block.InputPort(2).SamplingMode      = 'Sample';
        block.InputPort(2).DimensionsMode    = 'Fixed';
        block.InputPort(2).DirectFeedthrough = true; % ���͂��o�͊֐��Œ��ڗ��p����
        
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
                % �v�m�F
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
        fwrite(mySerial,'@SRVO1,', 'char'); % �T�[�{ON�w��
%         disp('!!-----ServoON Start-----!!')
        while ~manip.servo_state
            fwrite(mySerial,'@?OPT1,', 'char'); % �I�v�V�������i��ԁj�̓ǂݏo��
            if manip.chkNum == 2560 || manip.chkNum == 2048
                if manip.servo_state == 0
                    manip.servo_state = 1;
                end
            % �T�[�{��Ԃ����ł�ON�̏ꍇ�̉����ԍ��F2056�A2508�A2568�A2570
            elseif manip.chkNum == 2056 || manip.chkNum == 2058 || manip.chkNum == 2568 || manip.chkNum == 2570
                break;
            end
        end
        disp('!!-----ServoON Finish-----!!')
       %% Origin registration
        manip.mode = 2;
%         fwrite(mySerial,'@ORG,', 'char'); % ���_��A
% %         disp('!!-----Origin registration Start-----!!')
%         while ~manip.origin_state
%             fwrite(mySerial,'@?OPT1,', 'char'); % �I�v�V�������i��ԁj�̓ǂݏo��
% %             disp('!!-----Origin registration Doing-----!!')
%             % ���_��A�����̏ꍇ�̉����ԍ��F2584
%             if manip.chkNum == 2584
%                 if manip.origin_state == 0
%                     manip.origin_state = 1;
%                 end
%             % ���_��A���������łɊ����̏ꍇ�̉����ԍ��F2508�A2568
%             elseif manip.chkNum == 2058 || manip.chkNum == 2568
%                 break;
%             end
%         end
%         disp('!!-----Origin registration Finish-----!!')
       %% Move the Init position
        manip.mode = 3;
        % �����ʒu�ړ�
        initPos = num2str(block.DialogPrm(2).Data); % �����ʒu�擾
        speed = num2str(block.DialogPrm(3).Data); % ���x�擾
        %fwrite(mySerial,strcat('@S1=', num2str(speed), ','), 'char'); % ���x�w��
        fwrite(mySerial,strcat('@START1#P', num2str(initPos), '00,'), 'char'); % �����ʒu�ֈړ��w��
        while ~manip.moved_state
            fwrite(mySerial,'@?OPT1,', 'char'); % �I�v�V�������i��ԁj�̓ǂݏo��
            % �ړ������̏ꍇ�̉����ԍ��F2570
            if manip.chkNum == 2570
                if manip.moved_state == 0
                    manip.moved_state = 1;
                end 
            % �����ʒu�w�߂��x��Ȃ������ꍇ�A�w�߂��đ��M
            % 2584�A2056�F�T�[�{ON�A���_��A����
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
        % �ʒu�m�F
        if manip.judeg == 1
            manip.input = block.InputPort(2).Data;
            manip.mode = 5;
            fwrite(mySerial,'@?P1,', 'char'); % ���݈ʒu���̓ǂݏo��
            if manip.targetPos
                manip.judeg = 0;
            % 0�ʒu�̂Ƃ�
            elseif strcmp(num2str(manip.output), 'NaN') == 1
                manip.judeg = 0;
                manip.moved_state = 1;
            end
        % �I�v�V�������m�F
        elseif manip.targetPos == 1
            manip.mode = 6;
            fwrite(mySerial,'@?OPT1,,', 'char'); % �I�v�V�����̓ǂݏo��
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
        % �ڕW�w��    
        elseif block.InputPort(1).Data == 1 && manip.moved_state == 0
            manip.mode = 4;
            fwrite(mySerial,strcat('@START1#P', num2str(block.InputPort(2).Data), '00,'), 'char'); % targetPosition 
        % �ڕW�l�֓��B
        elseif block.InputPort(1).Data == 1 && manip.moved_state == 1
            block.OutputPort(1).Data = 1;        
        % �ҋ@
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
        % ��~
        fwrite(mySerial,'@STOP.1,', 'char');
        % �T�[�{OFF
        fwrite(mySerial,'@SRVO0,', 'char');
        
        fclose(mySerial);
        delete(mySerial);

    end

%%
    function SerialRcv(obj,event)
        % SerialRcv���œ��o�͂̏����A�}�j�s�����[�^�̐���͂ł��Ȃ��B
        
        if mySerial.BytesAvailable == 0
            return;
        end
        
        switch manip.mode
            % Start
            case 1 % �T�[�{ON
%                 disp('ServoON')
                checkOption();
            case 2 % ���_��A
%                 disp('Origin Registration')
                checkOption();
            case 3 % �����ʒu�ړ�
%                 disp('Initialize')
                checkOption();

            % Output
            case 4 % �ڕW�l�w��
%                disp('TargetPos')
                manip.judeg = 1;
            case 5 % �ړ���񊮗�����
%                disp('Move check position')
                checkPosition()                
            case 6 % �ړ���񊮗�����
%                disp('Move check option')
                checkOption();
%                disp(manip.targetPos)
            case 7 % �ڕW�l�ҋ@
%                disp('Wait')  
            otherwise
%                disp('other')
        end
        
        function checkOption() 
            buf10 = fscanf(mySerial); % �I�v�V��������M
            if buf10 > 4
                checkResponce = buf10(1:3); %��M���e�̊m�F
                checkLength = length(buf10); %������̒���
                startlm = regexp(buf10,'=');
                % �������I�v�V�������('OPT')�A���A�����񒷂�15('OPT1.1=65535')��菬����
                if strcmp(checkResponce, 'OPT') == 1 && checkLength < 15
                    manip.chkNum = str2double(buf10(startlm+1:checkLength));
                    return;
                else
                    return;
                end
            end
        end
        
        function checkPosition() 
            buf = fscanf(mySerial); % �I�v�V��������M
            if buf > 4
                checkResponce1 = buf(1); %��M���e�̊m�F
                checkLength1 = length(buf); %������̒���
                % �ʒu���('P')�A���A�����񒷂�12('P1.1=20000')��菬����
                if strcmp(checkResponce1, 'P') == 1 && checkLength1 < 13
                    startlm1 = regexp(buf,'=');
                    checkNum1 = str2double(buf(startlm1+1:checkLength1-4));
                    manip.output = checkNum1;
                    % �ړ������̏ꍇ
                    if checkNum1 == manip.input
                        manip.targetPos = 1;
                    end
                end
            end
        end
        
        % SerialRcv����block.InputPort/block.OutputPort�����Ă͂����Ȃ��B
        
        % �f�[�^��񓯊��œǂݎ��Ƃ��ɂ̂� BytesAvailable ���g�p
%         if mySerial.BytesAvailable == 0
%             return;
%         end
        
%         fwrite(mySerial,'@?P1,', 'char'); % ���݈ʒu���̓ǂݏo��
%         buf = fscanf(mySerial); % �I�v�V��������M
%         checkResponce1 = buf(1); %��M���e�̊m�F
%         checkLength1 = length(buf); %������̒���
%         
%         manip.a = checkLength1;
%         
%         % �ʒu���('P')�A���A�����񒷂�12('P1.1=20000')��菬����
%         if strcmp(checkResponce1, 'P') == 1 && checkLength1 < 13
%             startlm1 = regexp(buf,'=');
%             checkNum1 = str2double(buf(startlm1+1:checkLength1-4));
%             manip.output_pos = checkNum1;
            
            % �ړ������̏ꍇ
%             if checkNum1 == num2str(block.DialogPrm(2).Data)
%                 % "�ړ���"�I�v�V�����̓ǂݏo��
%                 fwrite(mySerial,'@?OPT1,,', 'char'); % ���݈ʒu���̓ǂݏo��
%                 buf = fscanf(mySerial); % dummy buffer
%                 buf10 = fscanf(mySerial); % �I�v�V��������M
%                 buf = fscanf(mySerial); % % dummy buffer
% %                     disp(buf10)
%                 checkLength2 = length(buf10); %������̒���
%                 % buf10�̕�����̒����m�F
%                 % �K������'OPT1.1=65535'�ł���Ƃ͌���Ȃ��̂�
%                 if checkLength2 > 4
%                     checkResponce2 = buf10(1:3); %��M���e�̊m�F
%                     % �I�v�V�����('O')�A���A�����񒷂�11('OPTB5.1=1')��菬����
%                     if strcmp(checkResponce2, 'OPT') == 1 && checkLength1 < 15
%                         startlm2 = regexp(buf10,'=');
%                         checkNum2 = str2double(buf10(startlm2+1:checkLength2));
%                         disp('chk2')
%                         disp(checkNum2)
%                         % �ڕW�ʒu�ړ������F2570�A2346
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
function l2_misumi_Z_ver2(block)

%%
% 作成者：M1奈須野智弘
% 作成日：2019年1月31日

% Help for Writing Level-2 M-File S-Functions:
%   web([docroot '/toolbox/simulink/sfg/f7-67622.html']

%   Copyright 2011 The MathWorks, Inc.

% define instance variables
mySerial = [];

manip.mode = 0;
manip.sw_down = 0;
manip.move_state = 0;
manip.responce = 0;

setup(block);

%% Set the block paremeters

    function setup(block)
        % Register the number of ports.
        block.NumInputPorts  = 2; % Action flag, Target position
        block.NumOutputPorts = 2; % Current state, Current position
        
        % Set up the states
        block.NumContStates = 0;
        block.NumDworks = 0;
        
        % Register the parameters.
        block.NumDialogPrms     = 3; % COM port, Baud Rate, Temporary position
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
        block.SampleTimes = [-1 0];
%         block.SampleTimes = [0 1];
        
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
            validateattributes(block.DialogPrm(2).Data, {'double'}, {'nonempty'}); % BaudRate
            validateattributes(block.DialogPrm(3).Data, {'double'}, {'nonempty'}); % Init position
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
                'BaudRate', block.DialogPrm(2).data, ...
                'DataBits', 8,...
                'Parity', 'none',...
                'StopBits', 1);
                % 'Terminator', 'LF')
                % 要確認
                % 'InputBufferSize', 1024*10, 
                % When the port avaailable, 
                % Serial Recieve CollbackFcn is done.
%                 set(mySerial, 'BytesAvailableFcn' ,@SerialRcv);
        end
        
        try
            fopen(mySerial);                
        catch me
            error(['Serial Port ', block.DialogPrm(1).data,' could not open!']);
        end
        
       %% Origin registration and Move the Init. Position
        while ~manip.sw_down
            initPos = num2str(block.DialogPrm(3).Data); % 初期位置取得
            tgt = lengthCheck(initPos);
            fwrite(mySerial,strcat('HI',tgt,','), 'char'); % 原点を登録し初期位置へ移動
            buf = fscanf(mySerial, '%c', 1);
            if strcmp(buf, 'b') == 1
                disp('Finish Origin registration')
            end
            if strcmp(buf, 'c') == 1
                manip.sw_down = 1;
            end
        end
        disp('Finish Initialize')
       %% Move the Init position
        initPos = num2str(block.DialogPrm(3).Data); % 初期位置取得
        tgt = lengthCheck(initPos);
        fwrite(mySerial,strcat('HT', tgt, ','), 'char'); % 初期位置へ移動指令
% %         while ~manip.move_state
% %             
% %             fwrite(mySerial,'HC,', 'char'); % Origin registration
% %             buf = fscanf(mySerial, '%c', 1);
% %             if strcmp(buf, 'e') == 1
% %                 manip.move_state = 1;
% %             end
% %             disp(buf)
% %             fwrite(mySerial,'HC,', 'char'); % Origin registration
% %             buf = fscanf(mySerial, '%c', 1);
% %             disp(buf)
% %         end
    end

%%
    function Output(block)
        
        if block.InputPort(1).Data == 0
            block.OutputPort(1).Data = 0;
            manip.move_state = 0;
        elseif block.InputPort(1).Data == 1 && manip.move_state == 0
            block.OutputPort(1).Data = 0;
            tgt = lengthCheck(num2str(block.InputPort(2).Data));
            disp(tgt)
            fwrite(mySerial,strcat('HT',tgt, ','), 'char'); % targetPosition
            while fscanf(mySerial,'%c',1) == 'd'
                manip.move_state = 0;
            end
            manip.move_state = 1;
        elseif block.InputPort(1).Data == 1 && manip.move_state == 1
            block.OutputPort(1).Data = 1;
        end
        
    end

%%
    function Terminate(block)
        
%         if mySerial.BytesAvailable > 0
%             fread(mySerial, mySerial.BytesAvailable, 'char');
%         end
        
        fclose(mySerial);
        delete(mySerial);

    end

%%
    function tgt = lengthCheck(org)
        orgLength = length(org);
        if orgLength == 1
            tgt = strcat('00', num2str(org));
        elseif orgLength == 2
            tgt = strcat('0', num2str(org));
        elseif orgLength == 3
            tgt = num2str(org);
        else
            tgt = '000';
        end
        if length(tgt) > 4
            tgt = '000';
        end
        return;
    end
%%
    function SerialRcv(obj,event)
        
        if mySerial.BytesAvailable == 0
            return;
        end
        
        buf = fscanf(mySerial, '%c', 1);
        manip.responce = buf;

    end

end
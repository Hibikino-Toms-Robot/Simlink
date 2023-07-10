%
clear all;
clc;

rosshutdown %ROSサーバを終了させる命令
rosinit     %ROSサーバを起動させる命令 

% Setting Parameters
run('settingParams.m')
% Setting GUI
run('GUI.mlapp')

% % Dummy Date用
% % 0 : test, 1 : run

% Flag_test = 0;

%各モデル名（Simulinkファイルの名前）
str = {'Sim1_Supervisor_OA', 'Sim2_ImageProcessor_OA', 'Sim5_OrthogonalArm_XY_OA', ...
    'Sim3_Cart_OA', 'Sim4_EndEffector_OA', 'Sim6_OrthogonalArm_Z_OA'}; 

% Sim1とSim2とSim5はクライアント側で起動
open_system(str{1});
%set_param(str{1}, 'SimulationCommand', 'Start'); %モデルの状態をStartにして実行だけを行う
open_system(str{2});
%set_param(str{2}, 'SimulationCommand', 'Start');
open_system(str{3});
%set_param(str{3}, 'SimulationCommand', 'Start');

% parfor : 複数のSimulinkファイルを同時に起動させる際に必要な関数
% Sim3,4,6 : ワーカー側で起動
parfor j = 4:6
    open_system(str{j});
%     in(j-3) = Simulink.SimulationInput(str{j});
    set_param(str{j}, 'SimulationCommand', 'Start'); %モデルの状態をStartにして実行だけを行う
end
% simJob = batchsim(in,'Pool',1);

%%
% Sim1の起動に対するGUIの同期
set(findobj(GUI_handle,'Tag','open_sim1'),'Value','Open');
set(findobj(GUI_handle,'Tag','start_sim1'),'Enable','on');
set(findobj(GUI_handle,'Tag','Lamp_sim1'),'Color',[1 1 0]);

% Sim2の起動に対するGUIの同期
set(findobj(GUI_handle,'Tag','open_sim2'),'Value','Open');
set(findobj(GUI_handle,'Tag','start_sim2'),'Enable','on');
set(findobj(GUI_handle,'Tag','Lamp_sim2'),'Color',[1 1 0]);

% Sim5の起動に対するGUIの同期
set(findobj(GUI_handle,'Tag','open_sim5'),'Value','Open');
set(findobj(GUI_handle,'Tag','start_sim5'),'Enable','on');
set(findobj(GUI_handle,'Tag','Lamp_sim5'),'Color',[1 1 0]);

% Sim3の起動に対するGUIの同期
set(findobj(GUI_handle,'Tag','open_sim3'),'Value','Open');
set(findobj(GUI_handle,'Tag','open_sim3'),'Enable','off');
set(findobj(GUI_handle,'Tag','start_sim3'),'Value','Start');
set(findobj(GUI_handle,'Tag','start_sim3'),'Enable','on');
set(findobj(GUI_handle,'Tag','Lamp_sim3'),'Color',[0 1 0]);

% Sim4の起動に対するGUIの同期
set(findobj(GUI_handle,'Tag','open_sim4'),'Value','Open');
set(findobj(GUI_handle,'Tag','open_sim4'),'Enable','off');
set(findobj(GUI_handle,'Tag','start_sim4'),'Value','Start');
set(findobj(GUI_handle,'Tag','start_sim4'),'Enable','on');
set(findobj(GUI_handle,'Tag','Lamp_sim4'),'Color',[0 1 0]);

% Sim6の起動に対するGUIの同期
set(findobj(GUI_handle,'Tag','open_sim6'),'Value','Open');
set(findobj(GUI_handle,'Tag','open_sim6'),'Enable','off');
set(findobj(GUI_handle,'Tag','start_sim6'),'Value','Start');
set(findobj(GUI_handle,'Tag','start_sim6'),'Enable','on');
set(findobj(GUI_handle,'Tag','Lamp_sim6'),'Color',[0 1 0]);


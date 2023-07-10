%
clear all;
clc;

rosshutdown %ROS�T�[�o���I�������閽��
rosinit     %ROS�T�[�o���N�������閽�� 

% Setting Parameters
run('settingParams.m')
% Setting GUI
run('GUI.mlapp')

% % Dummy Date�p
% % 0 : test, 1 : run

% Flag_test = 0;

%�e���f�����iSimulink�t�@�C���̖��O�j
str = {'Sim1_Supervisor_OA', 'Sim2_ImageProcessor_OA', 'Sim5_OrthogonalArm_XY_OA', ...
    'Sim3_Cart_OA', 'Sim4_EndEffector_OA', 'Sim6_OrthogonalArm_Z_OA'}; 

% Sim1��Sim2��Sim5�̓N���C�A���g���ŋN��
open_system(str{1});
%set_param(str{1}, 'SimulationCommand', 'Start'); %���f���̏�Ԃ�Start�ɂ��Ď��s�������s��
open_system(str{2});
%set_param(str{2}, 'SimulationCommand', 'Start');
open_system(str{3});
%set_param(str{3}, 'SimulationCommand', 'Start');

% parfor : ������Simulink�t�@�C���𓯎��ɋN��������ۂɕK�v�Ȋ֐�
% Sim3,4,6 : ���[�J�[���ŋN��
parfor j = 4:6
    open_system(str{j});
%     in(j-3) = Simulink.SimulationInput(str{j});
    set_param(str{j}, 'SimulationCommand', 'Start'); %���f���̏�Ԃ�Start�ɂ��Ď��s�������s��
end
% simJob = batchsim(in,'Pool',1);

%%
% Sim1�̋N���ɑ΂���GUI�̓���
set(findobj(GUI_handle,'Tag','open_sim1'),'Value','Open');
set(findobj(GUI_handle,'Tag','start_sim1'),'Enable','on');
set(findobj(GUI_handle,'Tag','Lamp_sim1'),'Color',[1 1 0]);

% Sim2�̋N���ɑ΂���GUI�̓���
set(findobj(GUI_handle,'Tag','open_sim2'),'Value','Open');
set(findobj(GUI_handle,'Tag','start_sim2'),'Enable','on');
set(findobj(GUI_handle,'Tag','Lamp_sim2'),'Color',[1 1 0]);

% Sim5�̋N���ɑ΂���GUI�̓���
set(findobj(GUI_handle,'Tag','open_sim5'),'Value','Open');
set(findobj(GUI_handle,'Tag','start_sim5'),'Enable','on');
set(findobj(GUI_handle,'Tag','Lamp_sim5'),'Color',[1 1 0]);

% Sim3�̋N���ɑ΂���GUI�̓���
set(findobj(GUI_handle,'Tag','open_sim3'),'Value','Open');
set(findobj(GUI_handle,'Tag','open_sim3'),'Enable','off');
set(findobj(GUI_handle,'Tag','start_sim3'),'Value','Start');
set(findobj(GUI_handle,'Tag','start_sim3'),'Enable','on');
set(findobj(GUI_handle,'Tag','Lamp_sim3'),'Color',[0 1 0]);

% Sim4�̋N���ɑ΂���GUI�̓���
set(findobj(GUI_handle,'Tag','open_sim4'),'Value','Open');
set(findobj(GUI_handle,'Tag','open_sim4'),'Enable','off');
set(findobj(GUI_handle,'Tag','start_sim4'),'Value','Start');
set(findobj(GUI_handle,'Tag','start_sim4'),'Enable','on');
set(findobj(GUI_handle,'Tag','Lamp_sim4'),'Color',[0 1 0]);

% Sim6�̋N���ɑ΂���GUI�̓���
set(findobj(GUI_handle,'Tag','open_sim6'),'Value','Open');
set(findobj(GUI_handle,'Tag','open_sim6'),'Enable','off');
set(findobj(GUI_handle,'Tag','start_sim6'),'Value','Start');
set(findobj(GUI_handle,'Tag','start_sim6'),'Enable','on');
set(findobj(GUI_handle,'Tag','Lamp_sim6'),'Color',[0 1 0]);


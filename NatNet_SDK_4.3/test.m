%% Test NatNetSDK 
% 2025-10-06 jkang first created

%%
clc

dllPath = 'C:\Users\Boram Kim\GitHub\NatNet_SDK_4.3\NatNetSDK\lib\x64\NatNetML.dll';
asm = NET.addAssembly(dllPath);

client = NatNetML.NatNetClientML();

localIP  = '127.0.0.1';   % MATLAB
serverIP = '127.0.0.1';   % Motive
client.Initialize(localIP, serverIP);

frame = client.GetLastFrameOfData();
disp(frame.nRigidBodies)
%%
clc;
client.Initialize('127.0.0.1','127.0.0.1');
pause(3)
frame = client.GetLastFrameOfData();
disp([frame.iFrame, frame.nRigidBodies])

%%

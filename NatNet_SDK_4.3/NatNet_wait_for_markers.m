% ===============================
% NatNet_capture_all_markers.m
% Logs all visible unlabeled markers from Motive
% ===============================

dllPath  = 'C:\Users\Boram Kim\GitHub\NatNet_SDK_4.3\NatNetSDK\lib\x64\NatNetML.dll';
localIP  = '127.0.0.1';
serverIP = '127.0.0.1';
duration = 10;   % seconds
pollRate = 100;  % Hz

asm = NET.addAssembly(dllPath);
client = NatNetML.NatNetClientML();
client.Initialize(localIP, serverIP);
fprintf('Streaming marker data from Motive for %.1f seconds...\n', duration);

% Store as structure for variable number of markers
data = struct('time', {}, 'markers', {});

t0 = tic;
while toc(t0) < duration
    frame = client.GetLastFrameOfData();
    t = frame.fTimestamp;
    
    if frame.nMarkers > 0
        n = frame.nMarkers;
        markerPos = zeros(n,3);
        for i = 1:n
            m = frame.OtherMarkers(i);
            markerPos(i,:) = [m.x, m.y, m.z];
        end
        data(end+1).time = t; %#ok<AGROW>
        data(end).markers = markerPos;
        fprintf('Frame %d | %d markers\n', frame.iFrame, n);
    else
        fprintf('.');
    end
    
    pause(1/pollRate);
end

client.Uninitialize();
disp('Capture complete.');

% Optional: save
save('NatNet_all_markers.mat','data');
fprintf('✅ Saved %d frames of marker data.\n', numel(data));

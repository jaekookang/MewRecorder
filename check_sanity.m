% Sanity checking script
pid = feature('getpid');
fprintf('matlab: %d\n', pid);

[~, result] = system(sprintf('tasklist /m /fi "PID eq %d" | findstr -i natnet', pid));
disp(result);

% Check in the current path
which('NatNetML.dll', '-all')
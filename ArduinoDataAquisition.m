%% MATLAB Controller for XY Scanner
clear; clc;

% --- Settings ---
port     = "COM5";
baudRate = 9600;
fileName = "scan_data.txt";

% 1. Initialization
s = serialport(port, baudRate);
configureTerminator(s, "LF");
pause(2); % Arduino Reset Wait

fileID = fopen(fileName, "wt");
fprintf(fileID, "x_mm y_mm thickness_mm\n");

% 2. Trigger Scan
disp("Sending 'Go' command...");
writeline(s, "G");
disp("Recording Data...");

scanning = true;
while scanning
    if s.NumBytesAvailable > 0
        line = readline(s);
        line = strtrim(line);

        if contains(line, "FINISHED")
            scanning = false;
            disp("Success: Scan Complete.");
        elseif ~isempty(line) && ~contains(line, "STARTING")
            fprintf(fileID, "%s\n", line);
            fprintf("Rec: %s\n", line);
        end
    end
    drawnow;
end

% 3. Cleanup
fclose(fileID);
clear s;
disp("Files closed. Serial port released.");
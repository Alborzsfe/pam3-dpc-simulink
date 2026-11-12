function [s, y] = pam3_packer_step(s, master, slave, command)
% Two fixed 32-symbol queues; output [valid_A valid_B bytes_A(16) bytes_B(16)].
% Per-channel packets are independent; file transport preserves their bytes.
if command == 3
    s = zeros(70, 1);
end
y = zeros(34, 1);
for channel = 0:1
    offset = channel * 35;
    buffer = offset + (1:32); count_index = offset + 33;
    frame_index = offset + 34; closed_index = offset + 35;
    if channel == 0
        trace = master;
    else
        trace = slave;
    end
    if s(closed_index)
        continue;
    end
    if trace(1)
        count = s(count_index) + 1;
        s(buffer(count)) = trace(2); s(count_index) = count;
    end
    is_last = trace(18) ~= 0;
    count = s(count_index);
    if count == 32 || is_last
        packet = pam3_packet_bytes(s(buffer(1:count)), channel, s(frame_index), is_last);
        y(channel+1) = 1;
        y(3+16*channel:18+16*channel) = double(packet);
        s(buffer) = 0; s(count_index) = 0;
        if is_last
            s(closed_index) = 1;
            s(frame_index) = mod(s(frame_index) + 1, 2^32);
        end
    end
end
end

function bytes = pam3_packet_bytes(symbols, channel, frame, is_last)
% Exact 128-bit record layout of the previous FPGA implementation.
symbols = double(symbols(:)); count = numel(symbols);
assert(count <= 32 && (count > 0 || is_last), 'PAM3:Packet', 'Invalid count.');
assert(channel == 0 || channel == 1, 'PAM3:Channel', 'Invalid channel.');
assert(frame >= 0 && frame < 2^32 && frame == floor(frame));
bits = zeros(128, 1);
for k = 1:count
    assert(any(symbols(k) == [-1, 0, 1]), 'PAM3:Symbol', 'Invalid symbol.');
    code = uint8(mod(symbols(k), 4));
    bits(2*k-1:2*k) = double(bitget(code, 1:2))';
end
bits(65:71) = double(bitget(uint8(count), 1:7))';
bits(72) = channel; bits(73) = double(is_last);
bits(74:105) = double(bitget(uint32(frame), 1:32))';
bytes = uint8(sum(reshape(bits, 8, 16) .* repmat((2.^(0:7))', 1, 16), 1))';
end

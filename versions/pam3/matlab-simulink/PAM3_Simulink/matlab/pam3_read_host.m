function records = pam3_read_host(filename)
fid = fopen(filename, 'rb');
assert(fid >= 0, 'PAM3:File', 'Cannot open host capture.');
cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>
raw = fread(fid, inf, '*uint8');
assert(mod(numel(raw), 16) == 0, 'PAM3:Truncated', 'Truncated packet.');
records = struct('channel', {}, 'frame', {}, 'last', {}, 'symbols', {});
closed = [false, false];
for k = 1:numel(raw)/16
    bytes = raw((k-1)*16+(1:16));
    bits = reshape(double(bitget(repmat(bytes', 8, 1), repmat((1:8)', 1, 16))), 128, 1);
    count = sum(bits(65:71) .* (2.^(0:6))');
    channel = bits(72); is_last = bits(73) ~= 0;
    frame = sum(bits(74:105) .* (2.^(0:31))');
    assert(count <= 32 && (count > 0 || is_last), 'PAM3:Count', 'Invalid count.');
    assert(~any(bits(106:128)), 'PAM3:Reserved', 'Reserved bits must be zero.');
    assert(~any(bits(2*count+1:64)), 'PAM3:Padding', 'Unused payload must be zero.');
    assert(~closed(channel+1), 'PAM3:AfterEnd', 'Unexpected record after capture end.');
    assert(frame == 0, 'PAM3:Frame', 'This reader expects one capture session.');
    symbols = zeros(count, 1);
    for j = 1:count
        code = bits(2*j-1) + 2*bits(2*j);
        assert(code ~= 2, 'PAM3:Code', 'Reserved symbol code 10.');
        symbols(j) = code;
        if code == 3
            symbols(j) = -1;
        end
    end
    closed(channel+1) = is_last;
    records(k) = struct('channel', channel, 'frame', frame, 'last', is_last, 'symbols', symbols); %#ok<AGROW>
end
assert(all(closed), 'PAM3:MissingEnd', 'Missing terminal channel records.');
end

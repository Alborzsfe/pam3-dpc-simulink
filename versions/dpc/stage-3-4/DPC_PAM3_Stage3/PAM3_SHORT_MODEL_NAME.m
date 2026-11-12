function short=PAM3_SHORT_MODEL_NAME(requested)
% Compact deterministic model identifier; no Java or external dependencies.
% Products stay below 2^53, so the integer rolling arithmetic is exact.
requested=char(requested);
h1=0;h2=0;
for c=double(requested)
    h1=mod(h1*65599+c,4294967296);
    h2=mod(h2*131+c,4294967296);
end
short=['D4_' dec2hex(h1,8) dec2hex(h2,8)];
end

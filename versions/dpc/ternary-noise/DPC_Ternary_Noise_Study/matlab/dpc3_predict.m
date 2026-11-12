function [powers,current_power,legs] = dpc3_predict(vabc,iabc,vdc,c)
% Balanced 50-Hz source, R-L filter, constant bridge vector over one Ts.
% Exact R-L integration with a rotating source; DC voltage frozen for one Ts.
assert(numel(vabc) == 3 && numel(iabc) == 3 && isfinite(vdc));
vabc = double(vabc(:)); iabc = double(iabc(:));
assert(all(isfinite(vabc)) && all(isfinite(iabc)));
e = (2*vabc(1)-vabc(2)-vabc(3))/3+1i*(vabc(2)-vabc(3))/sqrt(3);
i = (2*iabc(1)-iabc(2)-iabc(3))/3+1i*(iabc(2)-iabc(3))/sqrt(3);
ids = 0:7;
legs = [floor(ids/4);mod(floor(ids/2),2);mod(ids,2)];
u = max(0,vdc)*((2*legs(1,:)-legs(2,:)-legs(3,:))/3+ ...
    1i*(legs(2,:)-legs(3,:))/sqrt(3));
a = exp(-c.R*c.sample_time/c.L); rotation = exp(1i*c.omega*c.sample_time);
if c.R > 0, b = -expm1(-c.R*c.sample_time/c.L)/c.R;
else, b = c.sample_time/c.L; end
base = a*i+e*(rotation-a)/(c.R+1i*c.omega*c.L);
next_i = base-b*u; next_e = e*rotation;
s = 1.5*next_e*conj(next_i);
powers = [real(s);imag(s)]; % Source Q = 1.5*(v_beta*i_alpha-v_alpha*i_beta).
now = 1.5*e*conj(i); current_power = [real(now);imag(now)];
end

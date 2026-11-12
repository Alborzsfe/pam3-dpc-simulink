function [gates,audit,ids] = dpc3_table(sp,sq,sector,vabc,iabc,vdc,pref,qref,bp,bq,previous_legs,c)
% Nine EXPLICIT state pairs. Four binary corners retain the source table.
assert(ismember(sp,[-1,0,1]) && ismember(sq,[-1,0,1]));
assert(isfinite(pref) && isfinite(qref));
[predicted,current,legs] = dpc3_predict(vabc,iabc,vdc,c);
reference = [pref;qref]; baseline = dpc3_original_table(bp,bq,sector);
baseline_id = [4,2,1]*baseline;
tracking = sum(c.weights(:).*((predicted-reference)./c.scale(:)).^2,1);
baseline_cost = tracking(baseline_id+1);
distance = sum(legs ~= previous_legs(:),1);
ids = zeros(9,1); guarded = zeros(9,1);
for p = -1:1
    for q = -1:1
        row = 1+3*(p+1)+(q+1);
        if p ~= 0 && q ~= 0
            selected = dpc3_original_table((p+1)/2,(q+1)/2,sector);
            id = [4,2,1]*selected;
        else
            % A zero coordinate targets NO CHANGE of that power, not bit hold.
            delta = [p;q].*max(abs(reference-current),c.scale(:));
            target = current+delta;
            costs = sum(c.weights(:).*((predicted-target)./c.scale(:)).^2,1);
            best = min(costs); tolerance = 1e-12*max(1,abs(best));
            available = find(costs <= best+tolerance);
            [~,order] = min(distance(available)); id = available(order)-1;
            % Model-based guard ONLY: does not guarantee lower closed-loop THD.
            if c.prediction_guard && tracking(id+1) > baseline_cost+1e-12*max(1,baseline_cost)
                id = baseline_id; guarded(row) = 1;
            end
        end
        ids(row) = id;
    end
end
row = 1+3*(sp+1)+(sq+1); id = ids(row);
gates = dpc3_gate_encode(legs(:,id+1));
delta = predicted(:,id+1)-current;
audit = [sp;sq;sector;row;id;current;delta;tracking(id+1);baseline_cost;guarded(row);ids];
% audit columns: sp,sq,sector,row,id,P,Q,dP,dQ,J,J_original,guard, nine table IDs.
end

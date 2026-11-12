// Continuous, bounded-memory reconstruction of US11405248B2.
// Oldest ADC sample is in s_adc[7:0]; s_count valid contiguous samples.
// Exact fixed/literal-DC behaviour matches reference/model.py, including tail flush.
// Multi-lane mode unrolls dependent sample operations. 800 MS/s timing is NOT assumed.
module pam3_stream_core #(
    parameter integer LANES=1,
    parameter integer INDEX_W=64,
    parameter integer DC_ENABLE=0,
    parameter integer ADAPTIVE=0,
    parameter integer PLUS=140, MINUS=95, ZERO_PLUS=160, ZERO_MINUS=80,
    parameter integer DC_MIN_GATE=80, DC_ANCHOR=95,
    parameter integer INITIAL_PHASE=6,
    parameter integer COUNT_W=$clog2(LANES+1)
)(
    input wire clk, input wire rst,
    input wire s_valid, output wire s_ready,
    input wire [8*LANES-1:0] s_adc,
    input wire [COUNT_W-1:0] s_count, input wire s_last,
    output reg m_valid, input wire m_ready,
    output reg [LANES-1:0] m_mask,
    output reg [2*LANES-1:0] m_symbols,
    output reg [INDEX_W*LANES-1:0] m_indices,
    output reg [31:0] m_frame, output reg m_last,
    output reg protocol_error,
    output reg dbg_step,
    output reg [LANES-1:0] dbg_raw_mask, dbg_filtered_mask,
    output reg [8*LANES-1:0] dbg_corrected,
    output reg [2*LANES-1:0] dbg_raw, dbg_filtered,
    output reg [INDEX_W*LANES-1:0] dbg_tick
);
    localparam DATA=0, FLUSH=1, END_WAIT=2;
    localparam CANDIDATE_DELAY=16, TOTAL_DELAY=20;
    // Keep the three explicitly encoded states. Automatic FSM extraction sees
    // many unrolled lane predicates and can enumerate an enormous input table.
    (* fsm_encoding = "none" *) reg [1:0] state;
    reg [1:0] ns;
    reg [5:0] flush_left, nf;
    reg [INDEX_W-1:0] tick, ntick, frame_length, nlength, next_point, npoint;
    reg [31:0] frame_id, nframe;
    reg [7:0] previous_adc, nprevious;
    // This is signed PAM3 data, not a control FSM to re-encode.
    (* fsm_encoding = "none" *) reg signed [1:0] current_level;
    reg signed [1:0] nlevel;
    reg initialized, ninitialized;
    reg [7:0] dc_history[0:126], ndc_history[0:126];
    reg [7:0] dc_filled, ndc_filled;
    reg signed [1:0] raw_history[0:4], nraw_history[0:4];
    reg [4:0] raw_valid, nraw_valid;
    reg signed [1:0] level_memory[0:31], nlevel_memory[0:31];
    reg filter_initialized, nfilter_initialized;
    reg signed [1:0] previous_filtered, nprevious_filtered;
    reg edge_initialized, nedge_initialized, last_direction, ndirection;
    reg [INDEX_W-1:0] last_edge, nlast_edge;
    reg [3:0] pending_keep, npending_keep, pending_must, npending_must;
    reg [INDEX_W-1:0] pending_mid[0:3], npending_mid[0:3];
    reg [31:0] anchor_bits, nanchor_bits;
    reg [3:0] candidate_bits, ncandidate_bits, essential_bits, nessential_bits;
    reg [7:0] threshold_plus, nth_plus, threshold_minus, nth_minus;
    reg [7:0] threshold_zplus, nth_zplus, threshold_zminus, nth_zminus;
    reg signed [17:0] means[0:2], nmeans[0:2];
    reg [11:0] sums[0:2], nsums[0:2];
    reg [3:0] counts[0:2], ncounts[0:2], block_count, nblock_count;
    reg out_v, out_last, nerror;
    reg [LANES-1:0] out_mask;
    reg [2*LANES-1:0] out_symbols;
    reg [INDEX_W*LANES-1:0] out_indices;
    reg [31:0] out_frame;
    reg dstep;
    reg [LANES-1:0] draw_mask, dfiltered_mask;
    reg [8*LANES-1:0] dcorrected;
    reg [2*LANES-1:0] draw, dfiltered;
    reg [INDEX_W*LANES-1:0] dtick;
    integer lane,j,k,r,steps,value,minimum,maximum,corrected_value,class_id;
    integer diff_value,formula_value,gap_low,gap_high;
    reg real_sample, edge_now, must_now, direction_now, keep_now;
    reg cand_now, essential_now;
    reg signed [1:0] filtered_value;
    reg [INDEX_W-1:0] filter_index, edge_distance, midpoint, q, point_index;
    wire advance = !m_valid || m_ready;
    assign s_ready=(state==DATA) && advance;

    function automatic [19:0] block_average(input [19:0] total,input [3:0] n);
        begin
            case(n)
                3:block_average=total/3; 4:block_average=total/4;
                5:block_average=total/5; 6:block_average=total/6;
                7:block_average=total/7; 8:block_average=total/8;
                9:block_average=total/9; 10:block_average=total/10;
                11:block_average=total/11; 12:block_average=total/12;
                default:block_average=0;
            endcase
        end
    endfunction
    function automatic [7:0] clamp_threshold(input integer v);
        begin
            if(v<1)clamp_threshold=1;
            else if(v>254)clamp_threshold=254;
            else clamp_threshold=v[7:0];
        end
    endfunction

    always @* begin
        ns=state;nf=flush_left;ntick=tick;nlength=frame_length;npoint=next_point;nframe=frame_id;
        nprevious=previous_adc;nlevel=current_level;ninitialized=initialized;
        ndc_filled=dc_filled;nraw_valid=raw_valid;
        nfilter_initialized=filter_initialized;nprevious_filtered=previous_filtered;
        nedge_initialized=edge_initialized;ndirection=last_direction;nlast_edge=last_edge;
        npending_keep=pending_keep;npending_must=pending_must;
        nanchor_bits=anchor_bits;ncandidate_bits=candidate_bits;nessential_bits=essential_bits;
        nth_plus=threshold_plus;nth_minus=threshold_minus;nth_zplus=threshold_zplus;nth_zminus=threshold_zminus;
        nblock_count=block_count;
        out_v=m_valid;out_mask=m_mask;out_symbols=m_symbols;out_indices=m_indices;out_frame=m_frame;out_last=m_last;nerror=protocol_error;
        dstep=0;draw_mask=0;dfiltered_mask=0;dcorrected=0;draw=0;dfiltered=0;dtick=0;
        for(j=0;j<127;j=j+1)ndc_history[j]=dc_history[j];
        for(j=0;j<5;j=j+1)nraw_history[j]=raw_history[j];
        for(j=0;j<32;j=j+1)nlevel_memory[j]=level_memory[j];
        for(j=0;j<4;j=j+1)npending_mid[j]=pending_mid[j];
        for(j=0;j<3;j=j+1)begin nmeans[j]=means[j];nsums[j]=sums[j];ncounts[j]=counts[j];end
        steps=0;value=0;minimum=0;maximum=0;corrected_value=0;class_id=0;
        diff_value=0;formula_value=0;gap_low=0;gap_high=0;
        real_sample=0;edge_now=0;must_now=0;direction_now=0;keep_now=0;
        cand_now=0;essential_now=0;filtered_value=0;filter_index=0;edge_distance=0;midpoint=0;q=0;point_index=0;
        if(advance)begin
            out_v=0;
            if(state==END_WAIT && m_valid && m_ready && m_last)begin
                // Reset per-frame algorithm history only AFTER terminal output acceptance.
                ns=DATA;nf=0;ntick=0;nlength=0;npoint=INITIAL_PHASE;nframe=frame_id+1;
                nprevious=0;nlevel=0;ninitialized=0;ndc_filled=0;nraw_valid=0;
                nfilter_initialized=0;nprevious_filtered=0;nedge_initialized=0;ndirection=0;nlast_edge=0;
                npending_keep=0;npending_must=0;nanchor_bits=0;ncandidate_bits=0;nessential_bits=0;
                nth_plus=PLUS;nth_minus=MINUS;nth_zplus=ZERO_PLUS;nth_zminus=ZERO_MINUS;nblock_count=0;
                for(j=0;j<127;j=j+1)ndc_history[j]=0;
                for(j=0;j<5;j=j+1)nraw_history[j]=0;
                for(j=0;j<32;j=j+1)nlevel_memory[j]=0;
                for(j=0;j<4;j=j+1)npending_mid[j]=0;
                for(j=0;j<3;j=j+1)begin nsums[j]=0;ncounts[j]=0;end
                nmeans[0]=60*256;nmeans[1]=127*256;nmeans[2]=194*256;
            end else begin
                if(state==DATA && s_valid)begin
                    steps=s_count;
                    if(s_count>LANES)begin steps=LANES;nerror=1;end
                    if(s_count==0 && !s_last)nerror=1;
                    if(s_last)begin nlength=tick+steps;ns=FLUSH;nf=TOTAL_DELAY;end
                end else if(state==FLUSH)begin
                    steps=(flush_left>LANES)?LANES:flush_left;
                    nf=flush_left-steps;
                    if(flush_left<=LANES)ns=END_WAIT;
                end
                if(steps>0)begin
                    dstep=1;out_mask=0;out_symbols=0;out_indices=0;out_frame=frame_id;
                    out_last=(state==FLUSH && flush_left<=LANES);
                    for(lane=0;lane<LANES;lane=lane+1)begin
                        if(lane<steps)begin
                            real_sample=(state==DATA);
                            dtick[lane*INDEX_W+:INDEX_W]=ntick;
                            if(real_sample)begin
                                value=s_adc[lane*8+:8];minimum=value;maximum=value;
                                if(DC_ENABLE)begin
                                    for(j=0;j<127;j=j+1)if(j<ndc_filled)begin
                                        if(ndc_history[j]<minimum)minimum=ndc_history[j];
                                        if(ndc_history[j]>maximum)maximum=ndc_history[j];
                                    end
                                end
                                corrected_value=value;
                                if(DC_ENABLE && maximum>nth_plus && minimum<DC_MIN_GATE && value-minimum+DC_ANCHOR<255)
                                    corrected_value=value-minimum+DC_ANCHOR;
                                if(ninitialized)begin
                                    if(corrected_value>nprevious)begin
                                        if(corrected_value>nth_plus)nlevel=1;
                                        else if(corrected_value<nth_plus && corrected_value>nth_zminus)nlevel=0;
                                    end else if(corrected_value<nprevious)begin
                                        if(corrected_value<nth_minus)nlevel=-1;
                                        else if(corrected_value>nth_minus && corrected_value<nth_zplus)nlevel=0;
                                    end
                                end
                                nprevious=corrected_value;ninitialized=1;
                                draw_mask[lane]=1;dcorrected[lane*8+:8]=corrected_value;draw[lane*2+:2]=nlevel;
                                if(DC_ENABLE)begin
                                    for(j=126;j>0;j=j-1)ndc_history[j]=ndc_history[j-1];
                                    ndc_history[0]=value;if(ndc_filled<127)ndc_filled=ndc_filled+1;
                                end
                                if(ADAPTIVE)begin
                                    class_id=$signed(nlevel)+1;
                                    nsums[class_id]=nsums[class_id]+corrected_value;
                                    ncounts[class_id]=ncounts[class_id]+1;
                                    if(nblock_count==11)begin
                                        for(k=0;k<3;k=k+1)begin
                                            if(ncounts[k]>=3)begin
                                                diff_value=block_average({nsums[k],8'b0},ncounts[k])-$signed(nmeans[k]);
                                                nmeans[k]=$signed(nmeans[k])+(diff_value>>>3);
                                            end
                                        end
                                        gap_low=$signed(nmeans[1])-$signed(nmeans[0]);
                                        gap_high=$signed(nmeans[2])-$signed(nmeans[1]);
                                        if(gap_low>=12*256 && gap_high>=12*256)begin
                                            formula_value=($signed(nmeans[1])+gap_high*13/67+128)>>>8;nth_plus=clamp_threshold(formula_value);
                                            formula_value=($signed(nmeans[1])-gap_low*32/67+128)>>>8;nth_minus=clamp_threshold(formula_value);
                                            formula_value=($signed(nmeans[1])+gap_high*33/67+128)>>>8;nth_zplus=clamp_threshold(formula_value);
                                            formula_value=($signed(nmeans[1])-gap_low*47/67+128)>>>8;nth_zminus=clamp_threshold(formula_value);
                                        end
                                        nblock_count=0;for(k=0;k<3;k=k+1)begin nsums[k]=0;ncounts[k]=0;end
                                    end else nblock_count=nblock_count+1;
                                end
                            end
                            for(j=4;j>0;j=j-1)nraw_history[j]=nraw_history[j-1];
                            nraw_history[0]=nlevel;nraw_valid={nraw_valid[3:0],real_sample};
                            edge_now=0;must_now=0;keep_now=0;midpoint=0;
                            if(ntick>=2 && nraw_valid[2])begin
                                filtered_value=nraw_history[2];filter_index=ntick-2;
                                if(nraw_valid[3] && nraw_history[2]!=nraw_history[3])begin
                                    if(nraw_valid[1] && nraw_history[1]!=nraw_history[2] && nraw_history[3]==nraw_history[1])filtered_value=nraw_history[3];
                                    else if(nraw_valid[1] && nraw_valid[0] && nraw_history[1]==nraw_history[2] && nraw_history[0]!=nraw_history[2] && nraw_history[3]==nraw_history[0])filtered_value=nraw_history[3];
                                end else if(nraw_valid[4] && nraw_valid[3] && nraw_valid[1] && nraw_history[2]==nraw_history[3] && nraw_history[3]!=nraw_history[4] && nraw_history[1]!=nraw_history[2] && nraw_history[4]==nraw_history[1])filtered_value=nraw_history[4];
                                nlevel_memory[filter_index[4:0]]=filtered_value;
                                dfiltered_mask[lane]=1;dfiltered[lane*2+:2]=filtered_value;
                                if(nfilter_initialized && filtered_value!=nprevious_filtered)begin
                                    edge_now=1;direction_now=($signed(filtered_value)>$signed(nprevious_filtered));
                                    edge_distance=filter_index-nlast_edge;
                                    must_now=nedge_initialized && direction_now!=ndirection && edge_distance<=12;
                                    if(must_now)midpoint=nlast_edge+((edge_distance-1'b1)>>1);
                                    keep_now=must_now || !nedge_initialized || edge_distance>=9;
                                    nedge_initialized=1;nlast_edge=filter_index;ndirection=direction_now;
                                end
                                nfilter_initialized=1;nprevious_filtered=filtered_value;
                            end
                            // Current must edge cancels all retained edges in the previous 4 samples.
                            if(npending_keep[3] && npending_must[3] && !must_now)nanchor_bits[npending_mid[3][4:0]]=1;
                            for(j=3;j>0;j=j-1)begin
                                npending_mid[j]=npending_mid[j-1];
                                npending_keep[j]=npending_keep[j-1] && !must_now;
                                npending_must[j]=npending_must[j-1];
                            end
                            npending_mid[0]=midpoint;npending_keep[0]=edge_now && keep_now;npending_must[0]=must_now;
                            cand_now=0;essential_now=0;
                            if(ntick>=CANDIDATE_DELAY)begin
                                q=ntick-CANDIDATE_DELAY;
                                if(state==DATA || q<nlength)begin
                                    essential_now=nanchor_bits[q[4:0]];
                                    cand_now=essential_now || q==npoint;
                                    if(cand_now)npoint=q+12;
                                end
                                nanchor_bits[q[4:0]]=0;
                            end
                            if(ntick>=TOTAL_DELAY)begin
                                point_index=ntick-TOTAL_DELAY;
                                if(ncandidate_bits[3] && (nessential_bits[3] || !(cand_now || ncandidate_bits[0] || ncandidate_bits[1] || ncandidate_bits[2])))begin
                                    out_mask[lane]=1;
                                    out_indices[lane*INDEX_W+:INDEX_W]=point_index;
                                    out_symbols[lane*2+:2]=nlevel_memory[point_index[4:0]];
                                end
                            end
                            ncandidate_bits={ncandidate_bits[2:0],cand_now};
                            nessential_bits={nessential_bits[2:0],essential_now};
                            ntick=ntick+1;
                        end
                    end
                    out_v=(|out_mask) || out_last;
                end
            end
        end
    end

    always @(posedge clk)begin
        if(rst)begin
            state<=DATA;flush_left<=0;tick<=0;frame_length<=0;next_point<=INITIAL_PHASE;frame_id<=0;
            previous_adc<=0;current_level<=0;initialized<=0;dc_filled<=0;raw_valid<=0;
            filter_initialized<=0;previous_filtered<=0;edge_initialized<=0;last_direction<=0;last_edge<=0;
            pending_keep<=0;pending_must<=0;anchor_bits<=0;candidate_bits<=0;essential_bits<=0;
            threshold_plus<=PLUS;threshold_minus<=MINUS;threshold_zplus<=ZERO_PLUS;threshold_zminus<=ZERO_MINUS;block_count<=0;
            means[0]<=60*256;means[1]<=127*256;means[2]<=194*256;
            for(r=0;r<3;r=r+1)begin sums[r]<=0;counts[r]<=0;end
            for(r=0;r<127;r=r+1)dc_history[r]<=0;
            for(r=0;r<5;r=r+1)raw_history[r]<=0;
            for(r=0;r<32;r=r+1)level_memory[r]<=0;
            for(r=0;r<4;r=r+1)pending_mid[r]<=0;
            m_valid<=0;m_mask<=0;m_symbols<=0;m_indices<=0;m_frame<=0;m_last<=0;protocol_error<=0;
            dbg_step<=0;dbg_raw_mask<=0;dbg_filtered_mask<=0;dbg_corrected<=0;dbg_raw<=0;dbg_filtered<=0;dbg_tick<=0;
        end else begin
            state<=ns;flush_left<=nf;tick<=ntick;frame_length<=nlength;next_point<=npoint;frame_id<=nframe;
            previous_adc<=nprevious;current_level<=nlevel;initialized<=ninitialized;dc_filled<=ndc_filled;raw_valid<=nraw_valid;
            filter_initialized<=nfilter_initialized;previous_filtered<=nprevious_filtered;edge_initialized<=nedge_initialized;last_direction<=ndirection;last_edge<=nlast_edge;
            pending_keep<=npending_keep;pending_must<=npending_must;anchor_bits<=nanchor_bits;candidate_bits<=ncandidate_bits;essential_bits<=nessential_bits;
            threshold_plus<=nth_plus;threshold_minus<=nth_minus;threshold_zplus<=nth_zplus;threshold_zminus<=nth_zminus;block_count<=nblock_count;
            for(r=0;r<3;r=r+1)begin means[r]<=nmeans[r];sums[r]<=nsums[r];counts[r]<=ncounts[r];end
            for(r=0;r<127;r=r+1)dc_history[r]<=ndc_history[r];
            for(r=0;r<5;r=r+1)raw_history[r]<=nraw_history[r];
            for(r=0;r<32;r=r+1)level_memory[r]<=nlevel_memory[r];
            for(r=0;r<4;r=r+1)pending_mid[r]<=npending_mid[r];
            m_valid<=out_v;m_mask<=out_mask;m_symbols<=out_symbols;m_indices<=out_indices;m_frame<=out_frame;m_last<=out_last;protocol_error<=nerror;
            dbg_step<=dstep;dbg_raw_mask<=draw_mask;dbg_filtered_mask<=dfiltered_mask;dbg_corrected<=dcorrected;dbg_raw<=draw;dbg_filtered<=dfiltered;dbg_tick<=dtick;
        end
    end
endmodule

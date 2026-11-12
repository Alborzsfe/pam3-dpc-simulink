`timescale 1ns/1ps
module tb_stream;
    parameter LANES=1, DC=0, ADAPT=0;
    localparam CW=$clog2(LANES+1);
    reg clk=0; always #5 clk=~clk;
    reg rst=1,s_valid=0,s_last=0,m_ready=0;
    reg [LANES*8-1:0] s_adc=0;
    reg [CW-1:0] s_count=0;
    wire s_ready,m_valid,m_last,err,dbg_step;
    wire [LANES-1:0] mask,raw_mask,filt_mask;
    wire [2*LANES-1:0] syms,raw,filt;
    wire [64*LANES-1:0] indices,ticks;
    wire [8*LANES-1:0] corrected;
    wire [31:0] frame;
    pam3_stream_core #(.LANES(LANES),.DC_ENABLE(DC),.ADAPTIVE(ADAPT)) dut(
        .clk(clk),.rst(rst),.s_valid(s_valid),.s_ready(s_ready),.s_adc(s_adc),
        .s_count(s_count),.s_last(s_last),.m_valid(m_valid),.m_ready(m_ready),
        .m_mask(mask),.m_symbols(syms),.m_indices(indices),.m_frame(frame),.m_last(m_last),
        .protocol_error(err),.dbg_step(dbg_step),.dbg_raw_mask(raw_mask),
        .dbg_filtered_mask(filt_mask),.dbg_corrected(corrected),.dbg_raw(raw),
        .dbg_filtered(filt),.dbg_tick(ticks));
    string input_path,trace_path;
    integer fd,logfd,scan,n,lv,frames=1,completed=0,cycles=0,i,ack=0,eof=0;
    integer bubbles=1,seed=137,random_word,source_stalls=0,sink_stalls=0;
    reg [8*LANES-1:0] read_adc;
    reg held=0;
    reg [LANES-1:0] heldmask;
    reg [2*LANES-1:0] heldsyms;
    reg [64*LANES-1:0] heldidx;
    reg [31:0] heldframe;
    reg heldlast;
    initial begin
        if(!$value$plusargs("INPUT=%s",input_path)) $fatal(1,"Missing input");
        if(!$value$plusargs("TRACE=%s",trace_path)) $fatal(1,"Missing trace");
        scan=$value$plusargs("FRAMES=%d",frames);
        scan=$value$plusargs("BUBBLES=%d",bubbles);
        fd=$fopen(input_path,"r");logfd=$fopen(trace_path,"w");
        if(!fd || !logfd)$fatal(1,"File open");
        repeat(3)@(negedge clk);rst=0;
    end
    always @(negedge clk)begin
        if(!rst)begin
            random_word=$random(seed)&32'h7fffffff;
            m_ready=(!bubbles || random_word%5!=0);
            if(ack)s_valid=0;
            if(!s_valid && !eof && (!bubbles || random_word%4!=0))begin
                scan=$fscanf(fd,"%d %d %h\n",n,lv,read_adc);
                if(scan==3)begin s_adc=read_adc;s_count=n;s_last=lv;s_valid=1;end
                else eof=1;
            end
        end
    end
    always @(posedge clk)begin
        if(!rst)begin
            cycles=cycles+1;ack=s_valid && s_ready;
            if(s_valid && !s_ready)source_stalls=source_stalls+1;
            if(m_valid && !m_ready)sink_stalls=sink_stalls+1;
            if(held && (!m_valid || mask!==heldmask || syms!==heldsyms ||
                indices!==heldidx || frame!==heldframe || m_last!==heldlast))
                $fatal(1,"Output changed under backpressure");
            held=m_valid && !m_ready;
            heldmask=mask;heldsyms=syms;heldidx=indices;heldframe=frame;heldlast=m_last;
            if(m_valid && m_ready)begin
                for(i=0;i<LANES;i=i+1)if(mask[i])
                    $fdisplay(logfd,"O %0d %0d %0d",frame,indices[64*i+:64],$signed(syms[2*i+:2]));
                if(m_last)begin $fdisplay(logfd,"E %0d",frame);completed=completed+1;end
            end
            #1;
            if(err)$fatal(1,"Unexpected protocol_error");
            if(dbg_step)for(i=0;i<LANES;i=i+1)begin
                if(raw_mask[i])$fdisplay(logfd,"R %0d %0d %0d %0d",frame,ticks[64*i+:64],corrected[8*i+:8],$signed(raw[2*i+:2]));
                if(filt_mask[i])$fdisplay(logfd,"F %0d %0d %0d",frame,ticks[64*i+:64]-2,$signed(filt[2*i+:2]));
            end
            if(eof && completed==frames)begin
                $display("PASS frames=%0d cycles=%0d source_stalls=%0d sink_stalls=%0d",completed,cycles,source_stalls,sink_stalls);
                $fclose(fd);$fclose(logfd);$finish;
            end
            if(cycles>1000000)$fatal(1,"Timeout");
        end
    end
endmodule

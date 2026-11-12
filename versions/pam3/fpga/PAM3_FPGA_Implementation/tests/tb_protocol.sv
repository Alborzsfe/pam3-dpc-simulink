`timescale 1ns/1ps
module tb_protocol;
    reg clk=0;always #5 clk=~clk;
    reg rst=1,valid=0,last=0,ready=1;
    reg [3:0] count=0;
    reg [63:0] adc=64'h7f7f7f7f7f7f7f7f;
    wire sr,mv,ml,error,step;
    wire [7:0] mask,rawmask;
    wire [31:0] frame;
    integer i,beats=0,samples=0,terminals=0;
    pam3_stream_core #(.LANES(8)) dut(.clk(clk),.rst(rst),.s_valid(valid),.s_ready(sr),
        .s_adc(adc),.s_count(count),.s_last(last),.m_valid(mv),.m_ready(ready),.m_mask(mask),
        .m_frame(frame),.m_last(ml),.protocol_error(error),.dbg_step(step),.dbg_raw_mask(rawmask));
    task reset_core;
        begin @(negedge clk);rst=1;valid=0;last=0;repeat(2)@(negedge clk);rst=0;end
    endtask
    task send(input integer n,input integer l);
        begin
            @(negedge clk);valid=1;count=n;last=l;
            @(posedge clk);while(!sr)@(posedge clk);
            @(negedge clk);valid=0;last=0;
        end
    endtask
    initial begin
        reset_core();send(0,0);#1;if(!error)$fatal(1,"Zero-count error not reported");
        reset_core();send(9,0);#1;if(!error)$fatal(1,"Oversize beat error not reported");
        reset_core();send(0,1);
        wait(mv && ml);if(mask!=0 || frame!=0)$fatal(1,"Empty frame terminal invalid");
        repeat(3)@(negedge clk);
        send(3,1);wait(mv && ml);if(mask!=0 || frame!=1)$fatal(1,"Second tiny frame invalid");
        reset_core();send(8,0);reset_core();
        // Sustain 8 real samples on every clock for 100 consecutive clocks.
        @(negedge clk);valid=1;count=8;last=0;
        for(i=0;i<100;i=i+1)begin
            @(posedge clk);if(!sr)$fatal(1,"Unexpected stall on ready continuous stream");beats=beats+1;
            #1;if(!step || rawmask!=8'hff)$fatal(1,"Eight-lane throughput mismatch");samples=samples+8;
        end
        @(negedge clk);valid=0;
        if(error)$fatal(1,"Error after reset/continuous stream");
        $display("PASS protocol continuous_beats=%0d continuous_samples=%0d",beats,samples);$finish;
    end
    initial begin #100000;$fatal(1,"Timeout");end
endmodule

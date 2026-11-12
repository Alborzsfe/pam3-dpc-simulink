`timescale 1ns/1ps
module tb_analyzer;
    parameter LANES=8,DC=0,ADAPT=0;
    localparam CW=$clog2(LANES+1);
    reg clk=0;always #5 clk=~clk;
    reg rst=1,s_valid=0,s_last=0,m_ready=0;
    reg [8*LANES-1:0] a=0,b=0;
    reg [CW-1:0] count=0;
    wire s_ready,m_valid,m_last;
    wire [127:0] data;
    wire [3:0] errors;
`ifdef MAPPED_NETLIST
    pam3_analyzer_core dut(
`else
    pam3_analyzer_core #(.LANES(LANES),.DC_ENABLE(DC),.ADAPTIVE(ADAPT)) dut(
`endif
        .clk(clk),.rst(rst),.s_valid(s_valid),.s_ready(s_ready),.s_adc_a(a),.s_adc_b(b),
        .s_count(count),.s_last(s_last),.m_valid(m_valid),.m_ready(m_ready),
        .m_data(data),.m_last(m_last),.protocol_error(errors));
    string input_path,trace_path;
    integer fd,logfd,n,lv,scan,frames=1,completed=0,cycles=0,i,ack=0,eof=0;
    integer bubbles=1,seed=817,random_word,source_stalls=0,sink_stalls=0,records=0;
    reg [8*LANES-1:0] read_a,read_b;
    reg held=0,heldlast;
    reg [127:0] helddata;
    initial begin
        if(!$value$plusargs("INPUT=%s",input_path))$fatal(1,"Missing INPUT");
        if(!$value$plusargs("TRACE=%s",trace_path))$fatal(1,"Missing TRACE");
        scan=$value$plusargs("FRAMES=%d",frames);scan=$value$plusargs("BUBBLES=%d",bubbles);
        fd=$fopen(input_path,"r");logfd=$fopen(trace_path,"w");
        if(!fd || !logfd)$fatal(1,"File open");
        repeat(3)@(negedge clk);rst=0;
    end
    always @(negedge clk)if(!rst)begin
        random_word=$random(seed)&32'h7fffffff;
        m_ready=!bubbles || ((cycles%509>=180) && random_word%4!=0);
        if(ack)s_valid=0;
        if(!s_valid && !eof && (!bubbles || random_word%5!=0))begin
            scan=$fscanf(fd,"%d %d %h %h\n",n,lv,read_a,read_b);
            if(scan==4)begin count=n;s_last=lv;a=read_a;b=read_b;s_valid=1;end
            else eof=1;
        end
    end
    always @(posedge clk)if(!rst)begin
        cycles=cycles+1;ack=s_valid && s_ready;
        if(s_valid && !s_ready)source_stalls=source_stalls+1;
        if(m_valid && !m_ready)sink_stalls=sink_stalls+1;
        if(held && (!m_valid || data!==helddata || m_last!==heldlast))$fatal(1,"Host record changed while stalled");
        held=m_valid && !m_ready;helddata=data;heldlast=m_last;
        if(m_valid && m_ready)begin
            if(m_last!==data[72])$fatal(1,"Last header mismatch");
            $fdisplay(logfd,"%032h",data);records=records+1;
            if(m_last)completed=completed+1;
        end
        #1;
        if(errors)$fatal(1,"Unexpected protocol error: %h",errors);
        if(eof && completed==2*frames)begin
            $display("PASS frames=%0d cycles=%0d records=%0d source_stalls=%0d sink_stalls=%0d",completed,cycles,records,source_stalls,sink_stalls);
            $fclose(fd);$fclose(logfd);$finish;
        end
        if(cycles>1500000)$fatal(1,"Timeout");
    end
endmodule

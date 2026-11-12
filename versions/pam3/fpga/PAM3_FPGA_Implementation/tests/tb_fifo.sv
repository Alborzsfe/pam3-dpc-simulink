`timescale 1ns/1ps
module tb_fifo;
    reg clk=0;always #5 clk=~clk;
    reg rst=1,cv=0,ready=0;
    reg [31:0] data=0;
    wire valid,overflow;
    wire [31:0] out,drops;
    wire [3:0] occupancy;
    pam3_capture_fifo #(.WIDTH(32),.LOG_DEPTH(3)) dut(
        .clk(clk),.rst(rst),.capture_valid(cv),.capture_data(data),.m_valid(valid),
        .m_ready(ready),.m_data(out),.overflow(overflow),.dropped_beats(drops),.occupancy(occupancy));
    reg [31:0] queue[0:7];
    integer rd=0,wr=0,n=0,expected_drops=0,checked=0,seed=843,rv,cycles=0;
    reg pop,push;
    initial begin repeat(3)@(negedge clk);rst=0;end
    always @(negedge clk)if(!rst)begin
        rv=$random(seed)&32'h7fffffff;
        if(cycles<3000)begin cv=rv%5!=0;ready=rv%6==0;end
        else if(cycles<3100)begin cv=0;ready=1;end
        else begin cv=rv%4!=0;ready=rv%4!=1;end
        data=data+1;
    end
    always @(posedge clk)begin
        if(rst)begin rd=0;wr=0;n=0;expected_drops=0;end
        else begin
            cycles=cycles+1;
            if(valid!==(n!=0) || occupancy!==n)$fatal(1,"FIFO occupancy mismatch");
            if(valid && out!==queue[rd])$fatal(1,"FIFO data mismatch");
            pop=(n!=0) && ready;push=cv && (n<8 || pop);
            if(pop)begin rd=(rd+1)%8;n=n-1;checked=checked+1;end
            if(push)begin queue[wr]=data;wr=(wr+1)%8;n=n+1;end
            if(cv && !push)expected_drops=expected_drops+1;
            #1;
            if(drops!==expected_drops || overflow!==(expected_drops!=0))$fatal(1,"FIFO loss accounting mismatch");
            if(cycles==6000)begin
                if(checked<500 || expected_drops<500)$fatal(1,"Insufficient FIFO coverage");
                $display("PASS fifo checked=%0d dropped=%0d cycles=%0d",checked,expected_drops,cycles);$finish;
            end
        end
    end
endmodule

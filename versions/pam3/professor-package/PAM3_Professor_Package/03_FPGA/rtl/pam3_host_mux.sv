// Registered round-robin arbiter. Packet format is in docs/INTERFACES.md.
module pam3_host_mux(
    input wire clk,rst,
    input wire a_valid,output wire a_ready,input wire [63:0] a_data,
    input wire [6:0] a_count,input wire [31:0] a_frame,input wire a_last,
    input wire b_valid,output wire b_ready,input wire [63:0] b_data,
    input wire [6:0] b_count,input wire [31:0] b_frame,input wire b_last,
    output reg m_valid,input wire m_ready,output reg [127:0] m_data,output reg m_last
);
    reg prefer_b;
    wire select_b=b_valid && (!a_valid || prefer_b);
    wire available=!m_valid || m_ready;
    assign a_ready=available && a_valid && !select_b;
    assign b_ready=available && b_valid && select_b;
    always @(posedge clk)begin
        if(rst)begin m_valid<=0;m_data<=0;m_last<=0;prefer_b<=0;end
        else if(available)begin
            m_valid<=a_valid || b_valid;
            if(select_b)begin
                m_data<={23'b0,b_frame,b_last,1'b1,b_count,b_data};m_last<=b_last;prefer_b<=0;
            end else if(a_valid)begin
                m_data<={23'b0,a_frame,a_last,1'b0,a_count,a_data};m_last<=a_last;prefer_b<=1;
            end
        end
    end
endmodule

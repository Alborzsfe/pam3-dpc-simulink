// Single-clock capture buffer for a producer that cannot pause.
// A full-buffer arrival is explicitly lost and counted; finite buffering cannot
// repair a sustained rate mismatch. CDC belongs in the board-specific ADC adapter.
module pam3_capture_fifo #(
    parameter integer WIDTH=133, LOG_DEPTH=8
)(
    input wire clk,rst,input wire capture_valid,input wire [WIDTH-1:0] capture_data,
    output wire m_valid,input wire m_ready,output wire [WIDTH-1:0] m_data,
    output reg overflow,output reg [31:0] dropped_beats,
    output wire [LOG_DEPTH:0] occupancy
);
    localparam DEPTH=1<<LOG_DEPTH;
    reg [WIDTH-1:0] memory[0:DEPTH-1];
    reg [LOG_DEPTH-1:0] rd,wr;
    reg [LOG_DEPTH:0] count;
    wire pop=(count!=0) && m_ready;
    wire push=capture_valid && ((count<DEPTH) || pop);
    assign m_valid=count!=0;
    assign m_data=memory[rd];
    assign occupancy=count;
    always @(posedge clk)begin
        if(rst)begin rd<=0;wr<=0;count<=0;overflow<=0;dropped_beats<=0;end
        else begin
            if(push)begin memory[wr]<=capture_data;wr<=wr+1'b1;end
            if(pop)rd<=rd+1'b1;
            case({push,pop})2'b10:count<=count+1'b1;2'b01:count<=count-1'b1;default:count<=count;endcase
            if(capture_valid && !push)begin
                overflow<=1;
                if(dropped_beats!=32'hffffffff)dropped_beats<=dropped_beats+1'b1;
            end
        end
    end
endmodule

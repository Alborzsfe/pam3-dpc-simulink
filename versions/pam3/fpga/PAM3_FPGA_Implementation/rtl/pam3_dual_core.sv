// A shared ADC beat is accepted only when BOTH independent channels accept it.
module pam3_dual_core #(
    parameter integer LANES=8, DC_ENABLE=0, ADAPTIVE=0,
    parameter integer INDEX_W=64, COUNT_W=$clog2(LANES+1)
)(
    input wire clk,rst,input wire s_valid,output wire s_ready,
    input wire [8*LANES-1:0] s_adc_a,s_adc_b,
    input wire [COUNT_W-1:0] s_count,input wire s_last,
    output wire a_valid,input wire a_ready,
    output wire [LANES-1:0] a_mask,output wire [2*LANES-1:0] a_symbols,
    output wire [INDEX_W*LANES-1:0] a_indices,
    output wire [31:0] a_frame,output wire a_last,
    output wire b_valid,input wire b_ready,
    output wire [LANES-1:0] b_mask,output wire [2*LANES-1:0] b_symbols,
    output wire [INDEX_W*LANES-1:0] b_indices,
    output wire [31:0] b_frame,output wire b_last,
    output wire [1:0] protocol_error
);
    wire ra,rb;
    wire accepted_valid=s_valid && ra && rb;
    assign s_ready=ra && rb;
    pam3_stream_core #(.LANES(LANES),.INDEX_W(INDEX_W),.DC_ENABLE(DC_ENABLE),.ADAPTIVE(ADAPTIVE)) a(
        .clk(clk),.rst(rst),.s_valid(accepted_valid),.s_ready(ra),.s_adc(s_adc_a),.s_count(s_count),.s_last(s_last),
        .m_valid(a_valid),.m_ready(a_ready),.m_mask(a_mask),.m_symbols(a_symbols),.m_indices(a_indices),
        .m_frame(a_frame),.m_last(a_last),.protocol_error(protocol_error[0]));
    pam3_stream_core #(.LANES(LANES),.INDEX_W(INDEX_W),.DC_ENABLE(DC_ENABLE),.ADAPTIVE(ADAPTIVE)) b(
        .clk(clk),.rst(rst),.s_valid(accepted_valid),.s_ready(rb),.s_adc(s_adc_b),.s_count(s_count),.s_last(s_last),
        .m_valid(b_valid),.m_ready(b_ready),.m_mask(b_mask),.m_symbols(b_symbols),.m_indices(b_indices),
        .m_frame(b_frame),.m_last(b_last),.protocol_error(protocol_error[1]));
endmodule

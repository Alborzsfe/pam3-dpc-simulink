// Portable digital boundary: paired, deserialized 8-bit ADC samples -> host records.
// No board-specific ADC PHY, coupler, clock-domain crossing or USB controller.
module pam3_analyzer_core #(
    parameter integer LANES=8, DC_ENABLE=0, ADAPTIVE=0,
    parameter integer COUNT_W=$clog2(LANES+1)
)(
    input wire clk,rst,input wire s_valid,output wire s_ready,
    input wire [8*LANES-1:0] s_adc_a,s_adc_b,
    input wire [COUNT_W-1:0] s_count,input wire s_last,
    output wire m_valid,input wire m_ready,output wire [127:0] m_data,
    output wire m_last,output wire [3:0] protocol_error
);
    wire av,ar,al,bv,br,bl,pav,par,pal,pbv,pbr,pbl;
    wire [LANES-1:0] am,bm;
    wire [2*LANES-1:0] asy,bsy;
    wire [31:0] af,bf,paf,pbf;
    wire [63:0] pad,pbd;
    wire [6:0] pac,pbc;
    pam3_dual_core #(.LANES(LANES),.DC_ENABLE(DC_ENABLE),.ADAPTIVE(ADAPTIVE)) dec(
        .clk(clk),.rst(rst),.s_valid(s_valid),.s_ready(s_ready),.s_adc_a(s_adc_a),.s_adc_b(s_adc_b),
        .s_count(s_count),.s_last(s_last),.a_valid(av),.a_ready(ar),.a_mask(am),.a_symbols(asy),
        .a_frame(af),.a_last(al),.b_valid(bv),.b_ready(br),.b_mask(bm),.b_symbols(bsy),
        .b_frame(bf),.b_last(bl),.protocol_error(protocol_error[1:0]));
    pam3_symbol_packer #(.LANES(LANES)) pa(.clk(clk),.rst(rst),.s_valid(av),.s_ready(ar),
        .s_mask(am),.s_symbols(asy),.s_frame(af),.s_last(al),.m_valid(pav),.m_ready(par),
        .m_data(pad),.m_count(pac),.m_frame(paf),.m_last(pal),.protocol_error(protocol_error[2]));
    pam3_symbol_packer #(.LANES(LANES)) pb(.clk(clk),.rst(rst),.s_valid(bv),.s_ready(br),
        .s_mask(bm),.s_symbols(bsy),.s_frame(bf),.s_last(bl),.m_valid(pbv),.m_ready(pbr),
        .m_data(pbd),.m_count(pbc),.m_frame(pbf),.m_last(pbl),.protocol_error(protocol_error[3]));
    pam3_host_mux mux(.clk(clk),.rst(rst),.a_valid(pav),.a_ready(par),.a_data(pad),.a_count(pac),
        .a_frame(paf),.a_last(pal),.b_valid(pbv),.b_ready(pbr),.b_data(pbd),.b_count(pbc),
        .b_frame(pbf),.b_last(pbl),.m_valid(m_valid),.m_ready(m_ready),.m_data(m_data),.m_last(m_last));
endmodule

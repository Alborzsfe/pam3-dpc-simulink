// Compact sparse symbol lanes into oldest-first 64-bit words (32 symbols).
// Terminal words contain 0..32 valid symbols; empty frames have count=0,last=1.
module pam3_symbol_packer #(
    parameter integer LANES=8, BUF_SYMS=32+LANES
)(
    input wire clk,rst,input wire s_valid,output wire s_ready,
    input wire [LANES-1:0] s_mask,input wire [2*LANES-1:0] s_symbols,
    input wire [31:0] s_frame,input wire s_last,
    output reg m_valid,input wire m_ready,
    output reg [63:0] m_data,output reg [6:0] m_count,
    output reg [31:0] m_frame,output reg m_last,output reg protocol_error
);
    reg [2*BUF_SYMS-1:0] buffer,nbuffer;
    reg [6:0] used,nused;
    reg pending_last,npending;
    reg [31:0] frame_id,nframe;
    reg ov,ol,ne;
    reg [63:0] od;
    reg [6:0] oc;
    reg [31:0] oframe;
    integer i;
    assign s_ready=!pending_last && used<=BUF_SYMS-LANES;
    always @* begin
        nbuffer=buffer;nused=used;npending=pending_last;nframe=frame_id;ne=protocol_error;
        ov=m_valid;od=m_data;oc=m_count;oframe=m_frame;ol=m_last;
        if(!m_valid || m_ready)begin
            ov=0;
            if(used>=32 || pending_last)begin
                ov=1;oframe=frame_id;od=buffer[63:0];
                if(used>=32)begin
                    oc=32;ol=pending_last && used==32;
                    nbuffer=buffer>>64;nused=used-32;
                end else begin
                    oc=used;ol=1;nbuffer=0;nused=0;
                end
                if(ol)npending=0;
            end
        end
        if(s_valid && s_ready)begin
            if(nused==0)nframe=s_frame;
            else if(s_frame!=nframe)ne=1;
            for(i=0;i<LANES;i=i+1)if(s_mask[i])begin
                nbuffer[2*nused+:2]=s_symbols[2*i+:2];nused=nused+1;
            end
            if(s_last)npending=1;
        end
    end
    always @(posedge clk)begin
        if(rst)begin
            buffer<=0;used<=0;pending_last<=0;frame_id<=0;protocol_error<=0;
            m_valid<=0;m_data<=0;m_count<=0;m_frame<=0;m_last<=0;
        end else begin
            buffer<=nbuffer;used<=nused;pending_last<=npending;frame_id<=nframe;protocol_error<=ne;
            m_valid<=ov;m_data<=od;m_count<=oc;m_frame<=oframe;m_last<=ol;
        end
    end
endmodule

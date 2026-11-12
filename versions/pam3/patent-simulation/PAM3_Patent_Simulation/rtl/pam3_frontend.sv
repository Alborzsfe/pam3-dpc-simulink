// Synthesizable functional front end; NOT timing-closed at 800 MS/s.
// Sliding 128-sample extrema use a large combinational reduction here.
// A production target needs a pipelined/windowed extrema and sample-parallel design.
module pam3_frontend #(
    parameter integer DC_ENABLE=0,
    parameter integer WINDOW=128,
    parameter integer PLUS=140, MINUS=95, ZERO_PLUS=160, ZERO_MINUS=80,
    parameter integer DC_MIN_GATE=80, DC_ANCHOR=95
)(
    input wire clk, input wire rst, input wire in_valid, input wire [7:0] adc,
    output reg out_valid, output reg [7:0] corrected,
    output reg signed [1:0] level
);
    reg [7:0] history [0:WINDOW-2];
    reg [7:0] previous;
    reg initialized;
    integer count, j, minimum, maximum, candidate, value;
    reg signed [1:0] next_level;
    always @(posedge clk) begin
        if (rst) begin
            out_valid<=0; corrected<=0; level<=0; previous<=0;
            initialized<=0; count<=0;
            for(j=0;j<WINDOW-1;j=j+1) history[j]<=0;
        end else begin
            out_valid<=in_valid;
            if(in_valid) begin
                minimum=adc;maximum=adc;
                for(j=0;j<WINDOW-1;j=j+1) begin
                    if(j<count) begin
                        if(history[j]<minimum) minimum=history[j];
                        if(history[j]>maximum) maximum=history[j];
                    end
                end
                candidate=$unsigned(adc)-minimum+DC_ANCHOR;
                value=$unsigned(adc);
                if(DC_ENABLE && maximum>PLUS && minimum<DC_MIN_GATE && candidate<255)
                    value=candidate;
                next_level=level;
                if(initialized) begin
                    if(value>previous) begin
                        if(value>PLUS) next_level=1;
                        else if(value<PLUS && value>ZERO_MINUS) next_level=0;
                    end else if(value<previous) begin
                        if(value<MINUS) next_level=-1;
                        else if(value>MINUS && value<ZERO_PLUS) next_level=0;
                    end
                end
                corrected<=value;level<=next_level;previous<=value;initialized<=1;
                for(j=WINDOW-2;j>0;j=j-1)history[j]<=history[j-1];
                history[0]<=adc;
                if(count<WINDOW-1)count<=count+1;
            end
        end
    end
endmodule

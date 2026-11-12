`timescale 1ns/1ps
module tb_dual;
    reg clk=0;always #5 clk=~clk;
    reg rst=1,valid=0;
    reg [7:0] adc_a=0,adc_b=0;
    wire va0,vb0,va1,vb1;
    wire [7:0] ca0,cb0,ca1,cb1;
    wire signed [1:0] la0,lb0,la1,lb1;
    pam3_frontend #(.DC_ENABLE(0)) fa0(clk,rst,valid,adc_a,va0,ca0,la0);
    pam3_frontend #(.DC_ENABLE(0)) fb0(clk,rst,valid,adc_b,vb0,cb0,lb0);
    pam3_frontend #(.DC_ENABLE(1)) fa1(clk,rst,valid,adc_a,va1,ca1,la1);
    pam3_frontend #(.DC_ENABLE(1)) fb1(clk,rst,valid,adc_b,vb1,cb1,lb1);
    pam3_reference a();pam3_reference b();
    integer n,dc_mode,i,j,f,status,ea,eb,rawa,rawb,cora,corb,pa,pb,sa,sb,na,nb;
    string input_file,stages_file,symbols_a_file,symbols_b_file,vcd_file;
    initial begin
        if(!$value$plusargs("N=%d",n))$fatal(1,"N missing");
        if(n>20000)$fatal(1,"N exceeds simulation memory");
        if(!$value$plusargs("DC=%d",dc_mode))dc_mode=0;
        if(!$value$plusargs("INPUT=%s",input_file))$fatal(1,"INPUT missing");
        if(!$value$plusargs("STAGES=%s",stages_file))$fatal(1,"STAGES missing");
        if(!$value$plusargs("SYMA=%s",symbols_a_file))$fatal(1,"SYMA missing");
        if(!$value$plusargs("SYMB=%s",symbols_b_file))$fatal(1,"SYMB missing");
        if($value$plusargs("VCD=%s",vcd_file))begin $dumpfile(vcd_file);$dumpvars(0,tb_dual);end
        f=$fopen(input_file,"r");if(!f)$fatal(1,"Cannot open input");
        for(i=0;i<n;i=i+1)begin
            status=$fscanf(f,"%d %d\n",ea,eb);if(status!=2)$fatal(1,"Truncated input");
            a.adc[i]=ea;b.adc[i]=eb;
        end
        $fclose(f);a.process_frame(n,dc_mode);b.process_frame(n,dc_mode);
        f=$fopen(stages_file,"r");if(!f)$fatal(1,"Cannot open golden stages");
        repeat(3)@(negedge clk);rst=0;
        for(i=0;i<n;i=i+1)begin
            // Deterministic bubbles verify that input stalls do not advance history.
            if(i%17==3)begin
                valid=0;@(posedge clk);#1;
                if(va0||vb0||va1||vb1)$fatal(1,"valid stall failed");
                @(negedge clk);
            end
            valid=1;adc_a=a.adc[i];adc_b=b.adc[i];
            status=$fscanf(f,"%d %d %d %d\n",cora,rawa,corb,rawb);
            if(status!=4)$fatal(1,"Truncated golden stages");
            if(a.corrected[i]!=cora || a.raw_level[i]!=rawa || b.corrected[i]!=corb || b.raw_level[i]!=rawb)
                $fatal(1,"Behavioural stage mismatch at %d",i);
            @(posedge clk);#1;
            if(dc_mode==0)begin
                if(ca0!=cora || la0!=rawa || cb0!=corb || lb0!=rawb)$fatal(1,"RTL front end mismatch at %d",i);
            end else begin
                if(ca1!=cora || la1!=rawa || cb1!=corb || lb1!=rawb)$fatal(1,"RTL DC front end mismatch at %d",i);
            end
            @(negedge clk);
        end
        valid=0;$fclose(f);
        f=$fopen(symbols_a_file,"r");status=$fscanf(f,"%d\n",na);
        if(na!=a.output_count)$fatal(1,"A output count mismatch");
        for(j=0;j<na;j=j+1)begin
            status=$fscanf(f,"%d %d\n",pa,sa);
            if(pa!=a.points[j] || sa!=a.symbols[j])$fatal(1,"A symbol mismatch at %d",j);
        end
        $fclose(f);f=$fopen(symbols_b_file,"r");status=$fscanf(f,"%d\n",nb);
        if(nb!=b.output_count)$fatal(1,"B output count mismatch");
        for(j=0;j<nb;j=j+1)begin
            status=$fscanf(f,"%d %d\n",pb,sb);
            if(pb!=b.points[j] || sb!=b.symbols[j])$fatal(1,"B symbol mismatch at %d",j);
        end
        $fclose(f);
        $display("PASS samples_per_channel=%0d dc=%0d symbols_A=%0d symbols_B=%0d",n,dc_mode,na,nb);
        $finish;
    end
endmodule

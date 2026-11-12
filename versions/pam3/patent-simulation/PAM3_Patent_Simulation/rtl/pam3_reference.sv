// COMPLETE FRAME-BASED HDL FUNCTIONAL REFERENCE. Simulation-only; not production RTL.
// The all-frame tasks deliberately expose every intermediate stage for audit.
// Opposite edge directions form must midpoints, as interpreted from Fig. 2/4G.
module pam3_reference #(parameter integer MAX_SAMPLES=20000);
    integer adc [0:MAX_SAMPLES-1];
    integer corrected [0:MAX_SAMPLES-1];
    integer raw_level [0:MAX_SAMPLES-1];
    integer filtered [0:MAX_SAMPLES-1];
    integer edges [0:MAX_SAMPLES-1];
    integer direction [0:MAX_SAMPLES-1];
    integer must [0:MAX_SAMPLES-1];
    integer mid [0:MAX_SAMPLES-1];
    integer e1 [0:MAX_SAMPLES-1];
    integer m1 [0:MAX_SAMPLES-1];
    integer p1 [0:MAX_SAMPLES-1];
    integer anchors [0:MAX_SAMPLES-1];
    integer candidate_points [0:MAX_SAMPLES-1];
    integer essential [0:MAX_SAMPLES-1];
    integer points [0:MAX_SAMPLES-1];
    integer symbols [0:MAX_SAMPLES-1];
    integer output_count;
    task automatic process_frame(input integer n,input integer dc_enable);
        integer i,j,k,mn,mx,value,prev,lev,first,last,ec,fc,ac,cc,np,keep;
        begin
            lev=0;prev=adc[0];
            for(i=0;i<n;i=i+1)begin
                mn=adc[i];mx=adc[i];
                first=i-127;if(first<0)first=0;
                for(j=first;j<=i;j=j+1)begin
                    if(adc[j]<mn)mn=adc[j];if(adc[j]>mx)mx=adc[j];
                end
                value=adc[i];
                if(dc_enable && mx>140 && mn<80 && adc[i]-mn+95<255)
                    value=adc[i]-mn+95;
                corrected[i]=value;
                if(i>0)begin
                    if(value>prev)begin
                        if(value>140)lev=1;
                        else if(value<140 && value>80)lev=0;
                    end else if(value<prev)begin
                        if(value<95)lev=-1;
                        else if(value>95 && value<160)lev=0;
                    end
                end
                raw_level[i]=lev;filtered[i]=lev;prev=value;
            end
            first=0;
            while(first<n)begin
                last=first+1;
                while(last<n && raw_level[last]==raw_level[first])last=last+1;
                if(first>0 && last<n && last-first<=2 && raw_level[first-1]==raw_level[last])
                    for(j=first;j<last;j=j+1)filtered[j]=raw_level[first-1];
                first=last;
            end
            ec=0;
            for(i=1;i<n;i=i+1)if(filtered[i]!=filtered[i-1])begin
                edges[ec]=i;direction[ec]=(filtered[i]>filtered[i-1])?1:-1;
                must[ec]=0;mid[ec]=-1;
                if(ec>0 && direction[ec]!=direction[ec-1] && i-edges[ec-1]<=12)begin
                    must[ec]=1;mid[ec]=(edges[ec-1]+i-1)/2;
                end
                ec=ec+1;
            end
            fc=0;
            for(i=0;i<ec;i=i+1)begin
                prev=-9;if(i>0)prev=edges[i-1];
                if(must[i] || edges[i]-prev>=9)begin
                    e1[fc]=edges[i];m1[fc]=must[i];p1[fc]=mid[i];fc=fc+1;
                end
            end
            ac=0;
            for(i=0;i<fc;i=i+1)begin
                keep=1;j=i+1;
                while(j<fc && e1[j]-e1[i]<=4)begin
                    if(m1[j])keep=0;j=j+1;
                end
                if(keep && m1[i])begin anchors[ac]=p1[i];ac=ac+1;end
            end
            cc=0;np=6;
            for(i=0;i<ac;i=i+1)begin
                while(np<anchors[i])begin
                    candidate_points[cc]=np;essential[cc]=0;cc=cc+1;np=np+12;
                end
                candidate_points[cc]=anchors[i];essential[cc]=1;cc=cc+1;np=anchors[i]+12;
            end
            while(np<n)begin
                candidate_points[cc]=np;essential[cc]=0;cc=cc+1;np=np+12;
            end
            output_count=0;
            for(i=0;i<cc;i=i+1)begin
                keep=1;
                if(i<cc-1 && !essential[i] && candidate_points[i+1]-candidate_points[i]<=4)keep=0;
                if(keep)begin
                    points[output_count]=candidate_points[i];
                    symbols[output_count]=filtered[candidate_points[i]];
                    output_count=output_count+1;
                end
            end
        end
    endtask
endmodule

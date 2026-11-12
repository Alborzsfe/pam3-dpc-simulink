function legs = dpc3_original_table(bp,bq,sector)
% Bit-exact transcription of chart_29.xml in the supplied source SLX.
assert(ismember(bp,[0,1]) && ismember(bq,[0,1]));
assert(sector == round(sector) && sector >= 1 && sector <= 12);
% IDs are binary 4*legA+2*legB+legC, not the literature's V1..V6 numbering.
ids = [4,4,6,6,2,2,3,3,1,1,5,5; ... % bp=0,bq=0
       6,6,2,2,3,3,1,1,5,5,4,4; ... % bp=0,bq=1
       5,5,4,4,6,6,2,2,3,3,1,1; ... % bp=1,bq=0
       3,3,1,1,5,5,4,4,6,6,2,2];    % bp=1,bq=1
id = ids(1+2*bp+bq,sector);
legs = [floor(id/4);mod(floor(id/2),2);mod(id,2)];
end

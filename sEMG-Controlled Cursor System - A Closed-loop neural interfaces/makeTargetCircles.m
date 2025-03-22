function targ_circles = makeTargetCircles(TARG_POS, TARG_RAD)

a = linspace(0, 2*pi, 100);

targ_circles = nan(size(TARG_POS,1), length(a), size(TARG_POS,2));

for i=1:size(TARG_POS,2)
    
    targ_circles(1,:,i) = TARG_POS(1,i)+TARG_RAD(i)*cos(a);
    targ_circles(2,:,i) = TARG_POS(2,i)+TARG_RAD(i)*sin(a);
end
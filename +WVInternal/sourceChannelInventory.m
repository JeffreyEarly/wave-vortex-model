function channels = sourceChannelInventory()
% Enumerate the 13 individual nonhydrostatic volume-advection terms.
channels=table(strings(13,1),strings(13,1),strings(13,1),strings(13,1),VariableNames=["name","advecting","advected","factor"]);
r=0;
for component=["u","v","w","eta"]
    for direction=["x","y","z"]
        r=r+1;
        if direction=="x", a="u"; elseif direction=="y", a="v"; else, a="w"; end
        channels(r,:)={a+"*d"+direction+"("+component+")",a,component,direction};
    end
end
channels(13,:)={"w*eta*dlogN2","w","eta","stratification"};
end

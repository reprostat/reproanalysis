function cmap = gradCreate(c1,c2,step)
    cmap(1,:) = c1;
    cmap(step,:) = c2;
    gr = (c2-c1)/(step-1);
    c = c1;
    for i = 2:step-1
        c = c + gr;
        cmap(i,:) = c;
    end
end

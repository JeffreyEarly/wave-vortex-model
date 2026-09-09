function levels = constructionModeLevels(count)
% Fixed low, middle and cutoff stresses for one prepared candidate band.
levels=unique([1,2,ceil(count./[2 4 8]),max(1,count-2):count]);
levels=levels(levels<=count);
end

function [rect,meanSize] = session_movie_geometry(frameRects,pts,startTime,duration,fullRect)
% Fixed crop and mean foreground size over the presented movie interval.
% Weight by frame visibility time, including a final frame held beyond EOF.
% Blank frames have zero foreground size and do not enlarge the crop.
pts = pts(:);
stopTime = startTime+duration;
starts = pts; starts(1) = min(starts(1),startTime);
ends = [pts(2:end); stopTime];
weights = max(0,min(ends,stopTime)-max(starts,startTime));
sizes = frameRects(:,3:4)-frameRects(:,1:2);
visible = weights>0 & all(sizes>0,2);
rect = fullRect;
meanSize = fullRect(3:4)-fullRect(1:2);
if any(visible)
    rect = [min(frameRects(visible,1:2),[],1) max(frameRects(visible,3:4),[],1)];
    meanSize = sum(sizes.*weights,1)/sum(weights);
end
end

function rect = session_foreground_rect(alpha)
% Minimal nonzero-alpha bounds in Screen's [left top right bottom] coordinates.
% Only outer padding is excluded; transparent gaps inside the bounds remain.
% Empty means the frame has no foreground.
foreground = alpha > 0;
rows = find(any(foreground,2));
cols = find(any(foreground,1));
rect = [];
if ~isempty(rows) && ~isempty(cols)
    rect = [cols(1)-1 rows(1)-1 cols(end) rows(end)];
end
end

function pix_sz = convertDegreesPix(obj_deg, screen_dist, screen_sz, screen_pix)
% Exact inverse of convertPixDegrees. Distance and screen size use the same units.
pix_per_unit = screen_pix(1)/screen_sz(1);
pix_sz = 2 * screen_dist * tand(obj_deg/2) * pix_per_unit;
end

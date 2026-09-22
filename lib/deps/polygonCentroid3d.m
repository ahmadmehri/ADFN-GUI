function c = polygonCentroid3d(poly)
% geom3d polygonCentroid3d: area-weighted centroid of a planar 3D polygon
if size(poly,1) < 3, c = mean(poly,1); return; end
p0 = mean(poly, 1);
m  = size(poly,1);
num = zeros(1,3); den = 0;
for i = 1:m
    j = mod(i,m) + 1;
    tc = (p0 + poly(i,:) + poly(j,:)) / 3;
    ta = norm(cross(poly(i,:) - p0, poly(j,:) - p0)) / 2;
    num = num + ta * tc;
    den = den + ta;
end
if den > 0, c = num / den; else, c = p0; end

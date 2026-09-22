function a = polygonArea3d(poly)
% geom3d polygonArea3d: area of planar polygon(s) in 3D.
% Accepts one (n,3) polygon -> scalar, or a cell array -> column of areas.
if iscell(poly)
    a = zeros(numel(poly), 1);
    for i = 1:numel(poly), a(i) = polygonArea3d(poly{i}); end
    return
end
if size(poly,1) < 3, a = 0; return; end
c = mean(poly, 1);
v = 0;
m = size(poly,1);
for i = 1:m
    j = mod(i, m) + 1;
    v = v + norm(cross(poly(i,:) - c, poly(j,:) - c));
end
a = v / 2;

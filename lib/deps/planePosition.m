function pos = planePosition(point, plane)
% geom3d planePosition: 2D coordinates of 3D point(s) in the plane's basis
p0 = plane(1:3);
v1 = plane(4:6);
v2 = plane(7:9);
d  = point - p0;
% solve d = s*v1 + t*v2 in least-squares sense
B  = [v1(:), v2(:)];
st = (B \ d')';
pos = st;

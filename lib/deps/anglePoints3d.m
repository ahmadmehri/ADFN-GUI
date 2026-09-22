function a = anglePoints3d(p1, p2, p3)
% geom3d anglePoints3d: angle at P2 in the triangle P1-P2-P3 (radians).
% With two arguments, the angle between vectors P1 and P2.
if nargin == 2
    u = p1; v = p2;
else
    u = p1 - p2; v = p3 - p2;
end
a = atan2(norm(cross(u, v)), dot(u, v));

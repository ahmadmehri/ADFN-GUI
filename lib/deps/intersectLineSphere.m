function pts = intersectLineSphere(line, sphere, tol)
% geom3d intersectLineSphere: LINE=[x0 y0 z0 dx dy dz], SPHERE=[xc yc zc r]
% returns (2,3) intersection points, or NaN(2,3) when the line misses.
if nargin < 3, tol = 1e-12; end
p0 = line(1:3);  d = line(4:6);
c  = sphere(1:3); r = sphere(4);
a  = dot(d, d);
if a < tol, pts = NaN(2,3); return; end
f  = p0 - c;
b  = 2 * dot(f, d);
cc = dot(f, f) - r^2;
disc = b^2 - 4*a*cc;
if disc < -tol, pts = NaN(2,3); return; end
disc = max(disc, 0);
sq = sqrt(disc);
t1 = (-b - sq) / (2*a);
t2 = (-b + sq) / (2*a);
pts = [p0 + t1*d; p0 + t2*d];

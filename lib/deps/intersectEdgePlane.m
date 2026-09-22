function pts = intersectEdgePlane(edges, plane, tol)
% edges: (N,6) [x1 y1 z1 x2 y2 z2]; returns (N,3) intersection points,
% NaN rows where the edge is parallel to the plane or the hit lies off the segment.
if nargin < 3, tol = 1e-12; end
n  = planeNormal(plane);
p0 = plane(1:3);
d0 = edges(:,1:3);
dir = edges(:,4:6) - d0;
denom = dir * n(:);
t = ((p0 - d0) * n(:)) ./ denom;
pts = d0 + t .* dir;
bad = ~isfinite(denom) | abs(denom) < tol | t < -tol | t > 1 + tol;
pts(bad, :) = NaN;

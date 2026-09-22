function b = isCoplanar(pts, tol)
% geom3d isCoplanar: true if all points lie in a common plane
if nargin < 2, tol = 1e-9; end
if size(pts,1) < 4, b = true; return; end
c = mean(pts,1);
[~, S, ~] = svd(pts - c, 0);
b = S(3,3) <= tol * max(1, S(1,1));

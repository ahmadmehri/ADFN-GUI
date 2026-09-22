function poly2 = clipConvexPolygon3dHP(poly, plane)
% Clip a convex 3D polygon by the half-space of PLANE.
% Keeps vertices P with dot(P - planeOrigin, normal) <= 0 (geom3d convention).
if isempty(poly), poly2 = poly; return; end
if size(poly,1) > 1 && all(poly(1,:) == poly(end,:))
    poly = poly(1:end-1,:);              % drop duplicate closing vertex
end
o = plane(1:3);
n = planeNormal(plane); n = n(:)';
d = (poly - o) * n(:);                   % signed distance per vertex
inside = d <= 1e-12;
if all(inside), poly2 = poly; return; end
if ~any(inside), poly2 = zeros(0,3); return; end
m = size(poly,1);
poly2 = zeros(0,3);
for i = 1:m
    j = mod(i, m) + 1;
    Pi = poly(i,:); Pj = poly(j,:);
    di = d(i); dj = d(j);
    if di <= 1e-12
        poly2(end+1,:) = Pi; %#ok<AGROW>
    end
    if (di < 0) ~= (dj < 0)             % edge crosses the plane
        w = di / (di - dj);
        poly2(end+1,:) = Pi + w * (Pj - Pi); %#ok<AGROW>
    end
end

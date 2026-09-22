function b = isPointInPolygon(point, poly)
% Shim for geom2d/geom3d isPointInPolygon.
% 2D: direct inpolygon. 3D: project point(s) and polygon onto the polygon's
% plane, then inpolygon (points are assumed already coplanar, as produced by
% ADFNE's PolyXPlane3D).
tolIn = 1e-9;
if size(poly,2) == 2
    b = inpolygon(point(:,1), point(:,2), poly(:,1), poly(:,2));
    return
end
o  = poly(1,:);
u  = poly(2,:) - o; u = u / norm(u);
w  = cross(poly(2,:) - o, poly(3,:) - o); w = w / norm(w);
v  = cross(w, u);
P2 = [(poly - o) * u(:), (poly - o) * v(:)];
Q2 = [(point - o) * u(:), (point - o) * v(:)];
[in, on] = inpolygon(Q2(:,1), Q2(:,2), P2(:,1), P2(:,2));
b = in | on;
% tolerance: also accept points marginally outside due to round-off
if any(~b)
    for k = find(~b(:))'
        dmin = min(sqrt(sum((P2 - Q2(k,:)).^2, 2)));
        if dmin < tolIn, b(k) = true; end
    end
end

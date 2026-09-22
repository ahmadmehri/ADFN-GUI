function edge2 = clipEdge(edge, box)
% Shim for MatGeom/geom2d clipEdge (Liang-Barsky). box = [xmin xmax ymin ymax].
% Returns [x1 y1 x2 y2]; [0 0 0 0] if the edge lies fully outside the box
% (ADFNE tests clipped-out edges with all(cls==0,2)).
x1 = edge(1); y1 = edge(2); x2 = edge(3); y2 = edge(4);
dx = x2 - x1; dy = y2 - y1;
xmin = box(1); xmax = box(2); ymin = box(3); ymax = box(4);
p = [-dx, dx, -dy, dy];
q = [x1 - xmin, xmax - x1, y1 - ymin, ymax - y1];
u1 = 0; u2 = 1;
for k = 1:4
    if p(k) == 0
        if q(k) < 0, edge2 = [0 0 0 0]; return, end
    else
        r = q(k) / p(k);
        if p(k) < 0
            if r > u2, edge2 = [0 0 0 0]; return, end
            if r > u1, u1 = r; end
        else
            if r < u1, edge2 = [0 0 0 0]; return, end
            if r < u2, u2 = r; end
        end
    end
end
edge2 = [x1 + u1*dx, y1 + u1*dy, x1 + u2*dx, y1 + u2*dy];

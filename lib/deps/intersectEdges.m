function point = intersectEdges(edge1, edge2)
% Shim for geom2d intersectEdges. Returns [x y] intersection of two segments,
% [NaN NaN] if they do not intersect, [Inf Inf] if collinear & overlapping.
tol = 1e-12;
x1 = edge1(1); y1 = edge1(2); x2 = edge1(3); y2 = edge1(4);
x3 = edge2(1); y3 = edge2(2); x4 = edge2(3); y4 = edge2(4);
dx1 = x2 - x1; dy1 = y2 - y1;
dx2 = x4 - x3; dy2 = y4 - y3;
den = dx1*dy2 - dy1*dx2;
if abs(den) < tol
    % parallel; test collinearity + overlap
    if abs((x3 - x1)*dy1 - (y3 - y1)*dx1) < tol
        t0 = ((x3 - x1)*dx1 + (y3 - y1)*dy1) / (dx1^2 + dy1^2);
        t1 = ((x4 - x1)*dx1 + (y4 - y1)*dy1) / (dx1^2 + dy1^2);
        if max(t0,t1) >= -tol && min(t0,t1) <= 1+tol
            point = [Inf Inf]; return
        end
    end
    point = [NaN NaN]; return
end
t = ((x3 - x1)*dy2 - (y3 - y1)*dx2) / den;
s = ((x3 - x1)*dy1 - (y3 - y1)*dx1) / den;
if t >= -tol && t <= 1+tol && s >= -tol && s <= 1+tol
    point = [x1 + t*dx1, y1 + t*dy1];
else
    point = [NaN NaN];
end

function a = polygonArea(poly)
% Shim for geom2d polygonArea (signed area, CCW positive)
x = poly(:,1); y = poly(:,2);
a = 0.5 * sum(x .* circshift(y,-1) - circshift(x,-1) .* y);

function h = drawCylinder(cyl, N, varargin)
% Minimal shim for geom3d drawCylinder.
% cyl = [x1 y1 z1 x2 y2 z2 R]; N = number of facets around the circumference.
if nargin < 2 || isempty(N), N = 16; end
p1 = cyl(1:3); p2 = cyl(4:6); r = cyl(7);
ax = p2 - p1; L = norm(ax);
if L < eps || r <= 0, h = []; return; end
z = ax / L;
if abs(z(1)) < 0.9, tmp = [1 0 0]; else, tmp = [0 1 0]; end
x = cross(z, tmp); x = x / norm(x);
y = cross(z, x);
th = linspace(0, 2*pi, N+1)';
circ = r * (cos(th) * x + sin(th) * y);   % (N+1,3)
C1 = p1 + circ;
C2 = p2 + circ;
X = [C1(:,1) C2(:,1)];
Y = [C1(:,2) C2(:,2)];
Z = [C1(:,3) C2(:,3)];
washold = ishold; hold on;
h = surf(X, Y, Z, 'EdgeColor', 'none', varargin{:});
if ~washold, hold off; end

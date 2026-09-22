function plane = createPlane(varargin)
% geom3d plane: [x0 y0 z0  dx1 dy1 dz1  dx2 dy2 dz2]
if nargin == 1 && size(varargin{1},1) >= 3
    pts = varargin{1};
    p0 = pts(1,:);
    v1 = pts(2,:) - p0;
    v2 = pts(3,:) - p0;
elseif nargin == 2
    p0 = varargin{1}(:)';
    n  = varargin{2}(:)';
    n  = n / norm(n);
    if abs(n(1)) < 0.9, tmp = [1 0 0]; else, tmp = [0 1 0]; end
    v1 = cross(n, tmp); v1 = v1 / norm(v1);
    v2 = cross(n, v1);
    plane = [p0 v1 v2];
    return
else
    error('createPlane: unsupported input');
end
n = cross(v1, v2); n = n / norm(n);
v1 = v1 / norm(v1);
v2 = cross(n, v1);
plane = [p0 v1 v2];

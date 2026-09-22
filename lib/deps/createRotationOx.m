function T = createRotationOx(varargin)
% geom3d createRotationOx: (theta) | (origin, theta) | (x0,y0,z0,theta)
[o, theta] = parseRotArgs(varargin{:});
c = cos(theta); s = sin(theta);
R = [1 0 0 0; 0 c -s 0; 0 s c 0; 0 0 0 1];
T = aboutOrigin(R, o);

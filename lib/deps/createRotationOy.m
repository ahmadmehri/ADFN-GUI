function T = createRotationOy(varargin)
% geom3d createRotationOy: (theta) | (origin, theta) | (x0,y0,z0,theta)
[o, theta] = parseRotArgs(varargin{:});
c = cos(theta); s = sin(theta);
R = [c 0 s 0; 0 1 0 0; -s 0 c 0; 0 0 0 1];
T = aboutOrigin(R, o);

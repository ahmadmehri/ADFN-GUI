function T = createRotation3dLineAngle(line, theta)
% geom3d createRotation3dLineAngle: rotation of THETA about LINE = [x0 y0 z0 dx dy dz]
p0 = line(1:3);
u  = line(4:6); u = u / norm(u);
c = cos(theta); s = sin(theta); t = 1 - c;
x = u(1); y = u(2); z = u(3);
R = [t*x*x + c,    t*x*y - s*z,  t*x*z + s*y,  0; ...
     t*x*y + s*z,  t*y*y + c,    t*y*z - s*x,  0; ...
     t*x*z - s*y,  t*y*z + s*x,  t*z*z + c,    0; ...
     0            0             0             1];
T = createTranslation3d(p0) * R * createTranslation3d(-p0);

function T = aboutOrigin(R, o)
% conjugate a rotation matrix so it acts about the point o
if all(o == 0), T = R; return; end
T = createTranslation3d(o) * R * createTranslation3d(-o);

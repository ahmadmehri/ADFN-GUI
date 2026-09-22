function [X, Y, Z] = cylinder2P(R, N, r1, r2)
% Cylinder between two 3D points; delegates to ADFNE's own Cylinder2P3D.
[X, Y, Z] = Cylinder2P3D(R, N, r1, r2);

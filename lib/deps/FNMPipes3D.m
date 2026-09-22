function [pip, cas, cts, xts, ids, La] = FNMPipes3D(fnm)
% FNMPipes3D  (reconstruction of the missing ADFNE function)
% Builds the centroid-to-intersection "pipe network" of a 3D fracture network.
%
% For every pair of intersecting fractures (i,j) a node is placed at the
% midpoint of their intersection trace; two pipes connect that node to the
% centroid of fracture i and to the centroid of fracture j.
%
% input : fnm   cell(n) of (k,3) fracture polygons
% output: pip   (p,6)  pipe endpoints [x1 y1 z1 x2 y2 z2]
%         cas   (p,1)  cluster label carried by each pipe
%         cts   (n,3)  fracture centroids
%         xts   (m,3)  intersection-trace midpoints
%         ids   (m,2)  intersecting fracture index pairs
%         La    (n,1)  fracture cluster labels (from PolysX3D)
n   = numel(fnm);
cts = Centroids3D(fnm);
[X, I, La] = PolysX3D(fnm);            % intersections + cluster labels
m   = numel(I);
xts = zeros(m, 3);
ids = zeros(m, 2);
pip = zeros(2*m, 6);
cas = zeros(2*m, 1);
k = 0;
for e = 1:m
    pr = double(I{e});
    a = pr(1); b = pr(2);
    P = X{e};
    if isempty(P), continue; end
    mid = mean(P, 1);                  % midpoint of the intersection trace
    xts(e, :) = mid;
    ids(e, :) = [a b];
    k = k + 1; pip(k, :) = [cts(a, :), mid]; cas(k) = La(a);
    k = k + 1; pip(k, :) = [cts(b, :), mid]; cas(k) = La(b);
end
pip = pip(1:k, :);
cas = cas(1:k);
mask = any(ids ~= 0, 2);
xts = xts(mask, :);
ids = ids(mask, :);

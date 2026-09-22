function cts = Centroid3D(plys)
% Centroid3D (singular spelling used by PolyInfo3D / PolyToDipDir3D)
% Delegates to ADFNE's Centroids3D.
if ~iscell(plys), plys = {plys}; end
cts = Centroids3D(plys);

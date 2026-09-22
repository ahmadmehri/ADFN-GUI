function edge2 = clipEdgeE(edge, box, tn)
% clipEdge with the result rounded to TN significant decimals (ADFNE variant).
if nargin < 3, tn = 9; end
edge2 = clipEdge(edge, box);
if ~all(edge2 == 0), edge2 = round(edge2, tn); end

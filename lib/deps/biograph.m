function G = biograph(cm, ~)
% Compatibility shim: the Bioinformatics 'biograph' class was removed from
% MATLAB. Returns a modern digraph built from the same connectivity matrix,
% which supports plot(G), degree(G), conncomp(G), shortestpath(G), ...
G = digraph(logical(cm));

function T = composeTransforms3d(varargin)
% geom3d convention: first transform is applied first
T = varargin{1};
for i = 2:nargin
    T = varargin{i} * T;
end

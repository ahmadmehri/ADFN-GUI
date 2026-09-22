function T = createScaling3d(varargin)
if nargin==1, s = varargin{1}(:)'; if numel(s)==1, s=[s s s]; end
else, s = [varargin{:}]; end
T = diag([s(1) s(2) s(3) 1]);

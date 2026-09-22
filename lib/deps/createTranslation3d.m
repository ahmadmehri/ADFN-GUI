function T = createTranslation3d(varargin)
if nargin==1, v = varargin{1}; else, v = [varargin{:}]; end
T = [1 0 0 v(1); 0 1 0 v(2); 0 0 1 v(3); 0 0 0 1];

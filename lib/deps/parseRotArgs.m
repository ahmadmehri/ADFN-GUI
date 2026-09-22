function [o, theta] = parseRotArgs(varargin)
% shared argument parsing for the createRotationO* shims
switch nargin
    case 1, o = [0 0 0];               theta = varargin{1};
    case 2, o = varargin{1}(:)';       theta = varargin{2};
    case 4, o = [varargin{1:3}];       theta = varargin{4};
    otherwise, error('createRotationO*: unsupported argument list');
end
if numel(o) < 3, o = [0 0 0]; end

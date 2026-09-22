function varargout = transformPoint3d(varargin)
% geom3d transformPoint3d: (PTS, T) or (X, Y, Z, T)
if nargin == 2
    pts = varargin{1}; T = varargin{2};
    x = pts(:,1); y = pts(:,2); z = pts(:,3);
    sz = size(pts(:,1));
elseif nargin == 4
    x = varargin{1}; y = varargin{2}; z = varargin{3}; T = varargin{4};
    sz = size(x);
    x = x(:); y = y(:); z = z(:);
else
    error('transformPoint3d: expects (PTS,T) or (X,Y,Z,T)');
end
rx = x*T(1,1) + y*T(1,2) + z*T(1,3) + T(1,4);
ry = x*T(2,1) + y*T(2,2) + z*T(2,3) + T(2,4);
rz = x*T(3,1) + y*T(3,2) + z*T(3,3) + T(3,4);
if nargout <= 1
    varargout{1} = [rx, ry, rz];
else
    varargout{1} = reshape(rx, sz);
    varargout{2} = reshape(ry, sz);
    varargout{3} = reshape(rz, sz);
end

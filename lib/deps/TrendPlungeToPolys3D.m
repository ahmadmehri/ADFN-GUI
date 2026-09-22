function plys = TrendPlungeToPolys3D(src, cols, s, k)
% TrendPlungeToPolys3D
% Builds 3D fracture polygons from tabular trend/plunge (orientation) data.
%
% NOTE: this function is missing from the ADFNE 1.0 distribution and the
% original file format is not documented anywhere in the package. This is a
% reconstruction with an explicit, configurable column mapping - check COLS
% against your own data before trusting the result.
%
% Usage:
%   plys = TrendPlungeToPolys3D(src)
%   plys = TrendPlungeToPolys3D(src, cols, s, k)
%
% input : src   path to a delimited text file, OR a numeric matrix already
%               loaded (rows = fractures)
%         cols  struct mapping data columns, default:
%                 .x .y .z      = 1 2 3   centre coordinates
%                 .trend        = 4       trend of the POLE, degrees
%                 .plunge       = 5       plunge of the POLE, degrees
%                 .size         = 6       fracture size (diameter); 0/absent
%                                         falls back to the scalar S
%         s     default fracture size when cols.size is unavailable (0.2)
%         k     vertices per fracture polygon (4 = ADFNE-style quad,
%               higher = disc approximation), default 4
% output: plys  cell(n,1) of (k,3) polygons
%
% Part of the ADFNE GUI dependency layer.

if nargin < 4 || isempty(k), k = 4; end
if nargin < 3 || isempty(s), s = 0.2; end
if nargin < 2 || isempty(cols)
    cols = struct('x',1,'y',2,'z',3,'trend',4,'plunge',5,'size',6);
end

if ischar(src) || isstring(src)
    D = readmatrix(char(src));
else
    D = src;
end
D = D(all(isfinite(D(:, [cols.x cols.y cols.z cols.trend cols.plunge])), 2), :);
n = size(D, 1);

cts = D(:, [cols.x cols.y cols.z]);
tr  = deg2rad(D(:, cols.trend));
pl  = deg2rad(D(:, cols.plunge));

if isfield(cols,'size') && ~isempty(cols.size) && size(D,2) >= cols.size
    sz = D(:, cols.size);
else
    sz = repmat(s, n, 1);
end

% pole trend/plunge -> plane dip / dip direction
dip  = pi/2 - pl;
ddir = mod(tr + pi, 2*pi);

% polygon template in the local x = 0 plane (ADFNE convention)
th = linspace(0, 2*pi, k+1)';  th(end) = [];
unit = [zeros(k,1), cos(th), sin(th)];

plys = cell(n, 1);
for i = 1:n
    T = composeTransforms3d( ...
        createRotationOy(-pi/2 + dip(i)), ...
        createRotationOz(ddir(i)), ...
        createTranslation3d(cts(i,:)));
    plys{i} = transformPoint3d(unit * (sz(i)/2), T);
end
end

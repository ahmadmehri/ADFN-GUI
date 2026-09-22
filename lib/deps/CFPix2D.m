function cf = CFPix2D(img, w, weighted, conn)
% CFPix2D  Connectivity field of a binary pixel (porous) model.
% Same algorithm as ADFNE's CFPix, with selectable pixel connectivity.
%
% input : img       binary image (nonzero = open/conductive)
%         w         support (window) size in pixels, default 1
%         weighted  normalise by number of cells, default false
%         conn      pixel connectivity, 4 or 8, default 8
if nargin < 4, conn = 8; end
if nargin < 3, weighted = false; end
if nargin < 2, w = 1; end
img = double(img ~= 0);
[m, n] = size(img);
cf = zeros(0,0);
I = 0;
for i = 1:w:m
    I = I + 1; J = 0;
    for j = 1:w:n
        ims = img;
        i2 = min(i+w, m); j2 = min(j+w, n);
        ims(i:i2, j:j2) = 1;                       % insert support
        imc = bwlabel(ims, conn);                  % label connected components
        J = J + 1;
        cf(I, J) = sum(imc(:) == imc(min(i+1,m), min(j+1,n)));
    end
end
if weighted, cf = cf / numel(cf); end

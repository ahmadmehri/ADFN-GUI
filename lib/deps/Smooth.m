function B = Smooth(A, sigma)
% Minimal shim: Gaussian smoothing of a 2D matrix
if nargin < 2 || isempty(sigma), sigma = 1; end
if sigma <= 0, B = A; return, end
rad = max(1, ceil(3*sigma));
[xx, yy] = meshgrid(-rad:rad, -rad:rad);
k = exp(-(xx.^2 + yy.^2) / (2*sigma^2));
k = k / sum(k(:));
B = conv2(double(A), k, 'same');

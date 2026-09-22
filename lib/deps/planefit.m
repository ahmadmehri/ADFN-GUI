function C = planefit(x, y, z)
% Least-squares fit of z = C(1)*x + C(2)*y + C(3)
x = x(:); y = y(:); z = z(:);
A = [x, y, ones(numel(x),1)];
C = A \ z;

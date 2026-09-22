function alpha = circ_vmrnd(theta, kappa, n)
% Minimal shim for CircStat circ_vmrnd (Best & Fisher 1979 algorithm)
if nargin < 3, n = 1; end
if nargin < 2 || isempty(kappa), kappa = 1; end
if nargin < 1 || isempty(theta), theta = 0; end
if numel(n) > 1, N = n(1)*n(2); sz = n; else, N = n; sz = [n 1]; end
if kappa < 1e-6
    alpha = 2*pi*rand(N,1) - pi;                 % uniform circular
    alpha = reshape(alpha, sz); return
end
a = 1 + sqrt(1 + 4*kappa^2);
b = (a - sqrt(2*a)) / (2*kappa);
r = (1 + b^2) / (2*b);
alpha = zeros(N,1);
for j = 1:N
    while true
        u = rand(3,1);
        z = cos(pi*u(1));
        f = (1 + r*z) / (r + z);
        c = kappa*(r - f);
        if (c*(2 - c) - u(2) > 0) || (log(c/u(2)) + 1 - c >= 0)
            break
        end
    end
    alpha(j) = theta + sign(u(3) - 0.5) * acos(f);
    alpha(j) = angle(exp(1i*alpha(j)));
end
alpha = reshape(alpha, sz);

function h = drawBox(box, varargin)
% Minimal shim for geom2d drawBox; box = [xmin xmax ymin ymax]
xmin = box(1); xmax = box(2); ymin = box(3); ymax = box(4);
xv = [xmin xmax xmax xmin xmin];
yv = [ymin ymin ymax ymax ymin];
washold = ishold; hold on;
h = plot(xv, yv, varargin{:});
if ~washold, hold off; end

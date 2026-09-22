function n = planeNormal(plane)
n = cross(plane(:,4:6), plane(:,7:9), 2);
n = n ./ sqrt(sum(n.^2, 2));

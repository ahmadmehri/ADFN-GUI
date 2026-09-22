function [R, X] = Importance(A, B, scaled)
% {name}
% {desc}
%
% Usage :
% {form}
%
% input : {}
% output: {}
%
% Alghalandis Discrete Fracture Network Engineering (ADFNE)
% Author: Younes Fadakar Alghalandis
% Copyright (c) 2016 Alghalandis Computing @ http://alghalandis.net
% All rights reserved.

if nargin<3; scaled = true; end
if scaled
    inputs = ScaleM(A, 0, 1);
    outputs = Scale_R1(B, 0, 1);
else
    inputs = A;
    outputs = B;
end
X = inputs\outputs;
R = Scale_R1(X, 0, 1);

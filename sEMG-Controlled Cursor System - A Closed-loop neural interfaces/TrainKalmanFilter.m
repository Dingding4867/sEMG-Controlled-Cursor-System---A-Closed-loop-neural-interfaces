function [A, W, H, Q] = TrainKalmanFilter(Y, X)

%[A W C Q] = TrainKalmanFilter(Y, X)    (A. Orsborn, created 6-16-10)
%
%Trains the Kalman filter model:
%        X(k+1) = A*X(k) + W(k)   %feed-forward state transition model
%        Y(k)   = H*X(k) + Q(k)   %measurement model
%   where X is the state vector to be estimated with the model, and Y are
%   the measurements (e.g. X = kinematics, Y = neural data)
%
%input:    Y - measurement matrix (# observations x time)
%          X - state matrix   (# states x time)
%output:   A - state transition matrix (# states x # states)
%          W - state noise covariance matrix (# states x # states)
%          H - measurement model matrix (# observations x # states)
%          Q - measurement noise covariance matrix (# observations x # observations)
%

%check user inputs
[N_states, N_time]  = size(X);
[N_obs, N_time1]    = size(Y);

if N_time1 ~= N_time
    error('X and Y matrices must have same # of columns (i.e. time).\nsize(X) = %g  %g\nsize(Y) = %g %g', ...
        N_states, N_time, N_obs, N_time1)
end
clear Nt1


%A = X2*X1' (X1*X1')^-1
%hint: we're using the function pinv() to compute the matrix inverse. 
X1 = X(:, 1:end-1);
X2 = X(:, 2:end);
A = X2 * X1' * pinv(X1 * X1');  %FILLIN

%W = (X2 - A*X1)(X2 - A*X1)' / (# time points - 1)
W = (X2 - A * X1) * (X2 - A * X1)' / (N_time - 1); %FILLIN

%H = Y*X'(X*X')^-1
H = Y * X' * pinv(X * X'); %FILLIN

%Q = (Y-HX)(Y-HX)' / (# time points)
Q = (Y - H * X) * (Y - H * X)' / N_time; %FILLIN


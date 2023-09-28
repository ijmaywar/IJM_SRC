function    [y,h] = fir_nodelay(x,n,fp,qual)
%
%    [y,h] =fir_nodelay(x,n,fp,qual)
%     n is the length of symmetric FIR filter to use.
%     fp is the filter cut-off frequency relative to fs/2=1
%     qual is an optional qualifier to pass to fir1.
%     The filter is generated by a call to fir1:
%        h = fir1(n,fp,qual);
%     Optional 2nd output argument returns the filter used.
%
% Copyright (C) 2013-2016, Mark Johnson
% This is free software: you can redistribute it and/or modify it under the
% terms of the GNU General Public License as published by the Free Software 
% Foundation, either version 3 of the License, or any later version.
% See <http://www.gnu.org/licenses/>.
%
% This software is distributed in the hope that it will be useful, but 
% WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
% or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License 
% for more details.
%
% last modified: 24 Dec 2013

% force n to be even so that fir1 returns an odd symmetric filter
% which has a group delay of an integer number of samples
n = 2*round(n/2) ;

if nargin==4,
   h = fir1(n,fp,qual);
else
   h = fir1(n,fp);
end

noffs = floor(n/2) ;
if size(x,1)==1,
   x = x(:) ;
end
y = filter(h,1,[x(n:-1:2,:);x;x(end+(-1:-1:-n),:)]) ;
y = y(n+noffs-1+(1:size(x,1)),:);

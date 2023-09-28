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
%     24/12/13 mj: fixed bugs on lines 23 and 24.

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

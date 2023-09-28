function    [y,h] = fir_nodelay(x,n,fp,qual)

%     [y,h] =fir_nodelay(x,n,fc,qual)
%     Delay-free filtering using a linear-phase (symmetric) FIR filter
%     followed by group delay correction. Delay-free filtering is needed
%		when the relative timing between signals is important e.g., when 
%		integrating signals that have been sampled at different rates.
%
%		fir_nodelay is similar to the function filtfilt.m in Matlab and Octave 
%		but with better control over the filter steepness. However a drawback of 
%		using FIR filters is that they usually need a lot of support, i.e., each
%		output sample is computed from a large number of input samples. This sets
%		a minimum size on the vector to be filtered.
%
%		Inputs:
%     x is the signal to be filtered. It can be multi-channel with a signal in
%      each column, e.g., an acceleration matrix. The number of samples (i.e., the
%		 number of rows in x) must be larger than the filter length, n.
%     n is the length of symmetric FIR filter to use in units of input samples
%		 (i.e., samples of x). The length should be at least 4/fc. A longer filter
%		 gives a steeper cut-off.
%     fc is the filter cut-off frequency relative to 1=Nyquist frequency. If a single
%		 number is given, the filter is a low-pass or high-pass. If fc is a vector with 
%		 two numbers, the filter is a bandpass filter with lower and upper cut-off frequencies
%		 given by fc(1) and fc(2). For a bandpass filter, n should be at least 4/fc(1) or
%		 4/diff(fc) whichever is larger.
%     qual is an optional qualifier determining if the filter is:
%		 'low'  low-pass (the default value if fc has a single number)
%		 'high' high-pass
%
%		Returns:
%		y is the filtered signal with the same size as x.
%     h is the vector of filter coefficients used by fir_nodelay (a vector). This can be used 
%		 to plot the filter characteristic using freqz(h,1,1024,fs)
%		
%     The filter is generated by a call to built-in function fir1 using:
%		 h = fir1(n,fc,qual);
%		Note: h is always an odd length filter even if n is even. This is needed to ensure that
%		filter is both symmetric and has a group delay which is an integer number of samples.
%		The filter has a support of n samples, i.e., it uses n samples from x to compute each sample
%		in y. The input samples used are those n/2 samples before to n/2 samples after the sample number
%		being computed. This means that samples at the start and end of the y vector need input samples
%		before the start of x and after the end of x. These are faked by reversing the first n/2 samples
%		of x and concatenating them to the start of x. The same trick is used at the end of x. As a result,
%		the first and last n/2 samples in y are untrustworthy. This initial condition problem is true for
%		any filter but the FIR filter used here makes it easy to identify precisely which samples are
%		unreliable.
%
%		Example:
%		 % make a waveform with two harmonics - one at 1/20 and another at 1/4 of the sampling rate.
%		 x = sin(2*pi*0.05*(1:100)')+cos(2*pi*0.25*(1:100)');
%		 y = fir_nodelay(x,30,0.2)
%		 plot([x,y])
% 	    returns: The input signal has the first and fifth harmonic. Applying the low-pass filter
%		 removes most of the fifth harmonic so the output appears as a sinewave except for the first
%		 few samples which are affected by the filter startup transient.
%
%     Valid: Matlab, Octave
%     markjohnson@st-andrews.ac.uk
%     Last modified: 10 May 2017

n = floor(n/2)*2 ;   % n must be even for an integer group delay
if nargin==4,
   h = fir1(n,fp,qual);
else
   h = fir1(n,fp);
end

noffs = floor(n/2) ;
if size(x,1)==1,
   x = x(:) ;
end
y = filter(h,1,[x(noffs:-1:2,:);x;x(end+(-1:-1:-noffs),:)]) ;
y = y(n-1+(1:size(x,1)),:);

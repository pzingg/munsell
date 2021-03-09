% munsellbookaotf
%
% User interface for plotting pages from the Munsell Book of Colors
% Note that the colors do not look exactly the same as on the pages
% of the book because of visualization parameters, video displays
% etc, etc.
%
% Munsell spectra (AOTF) and their color coordinates are stored in file
% munsell400_700_5.mat where:
%
%               munsell         61x1250 matrix where each column is one spectrum
%                               measured from 400 nm to 700 nm with 5 nm interval.
%
%               S               1250x15 matrix where one row is the label of the
%                               corresponding spectrum in the munsell matrix. For
%                               example 1st row is the label of the 1st spectrum
%                               in munsell matrix, 2nd row is the label of 2nd
%                               spectrum and so on.
%
%               C               16x1250 matrix where in each column are the color
%                               coordinates of the corresponding spectra. The
%                               color coordinates are stored in a column in the
%                               following order:
%
%                               C(1)    x
%                               C(2)    y
%                               C(3)    z
%                               C(4)    X
%                               C(5)    Y
%                               C(6)    Z
%                               C(7)    R
%                               C(8)    G
%                               C(9)    B
%                               C(10)   L*
%                               C(11)   a*
%                               C(12)   b*
%                               C(13)   u
%                               C(14)   v
%                               C(15)   u*
%                               C(16)   v*
%
% See also:	munsellpageaotf
%

%************************************************************************
%  (C) J. Haanpalo      04-04-95                                        *
%                                                                       *
%  NOTE: This program is copyrighted in the sense that it               *
%  may be used for scientific purposes. The program as a whole, or      *
%  parts thereof, cannot be included or used in any commercial          *
%  application without written permission granted by its producents.    *
%  This program comes 'as it is' and with no warranty.                  *
%                                                                       *
%  All comments concerning this program may be sent to the              *
%  e-mail address 'haanpalo@lut.fi'.                                    *
%                                                                       *
%***********************************************************************/

figure(1);
clf reset;

set(gcf,'Color',[1 1 1],'numbertitle','off','Name','Munsellbook (AOTF) v. 1.1');

disp('Loading Munsell data');
load munselldata;
disp('OK');

[x, y] = size(spec);

% GREP PAGE NAMES FROM LABELS
[xindex, yindex] = max([loki == 'V']');
index = [];
P = [];
p = [];
c = 0;
for i=1:y
        str = loki(i, 1:yindex(i)-1);
        if(~strcmp(p, str))
                p = str;
                P = str2mat(P, p);
                c = c + 1;
        end
        index = [index c];
end
[nx,ny] = size(P);
P = P(2:nx,:);
[nx,ny] = size(P);

f1 = uimenu('label','Munsell1');
for i=1:nx/2
	callstr = ['munsellpageaotf(spec,loki,P,S,index,', int2str(i),')'];
	uimenu(f1,'label',mundir(i,:),'callback',callstr);
end

f2 = uimenu('label','Munsell2');
for i=nx/2+1:nx
	callstr = ['munsellpageaotf(spec,loki,P,S,index,', int2str(i),')'];
	uimenu(f2,'label',mundir(i,:),'callback',callstr);
end

callstr = ['clear S callstr f1 f2 i loki P nx ny spec p str c index', ...
	   ' mundir x y xindex yindex;figure(1);close;'];
uimenu('label','Quit','callback',callstr);

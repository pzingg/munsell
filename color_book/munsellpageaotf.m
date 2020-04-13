function munsellpageaotf(munsell,S,P,C,index,ind)
% function munsellpageaotf(munsell,S,P,C,index,ind)
%
% Plots one page from the Munsell Book of Colors.
%
% Parameters:   munsell         matrix where spectra are stored.
%               S               labels of spectra.
%               P               names of munsell pages.
%               C               color coordinates for spectra
%               index           page indexes for spectra
%               ind             index of current page
%
% See also:     munsellbookaotf
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

[r,c] = size(munsell);

% INITIALIZE PARAMETERS
gam = 0.5;
j = 1;
spec = [];
for i=1:c
	if(index(i) == ind)
		labels = [labels;S(i,:)];
                spec = [spec munsell(:,i)];
		R(j) = C(7,i);
		G(j) = C(8,i);
		B(j) = C(9,i);
		j = j + 1;
	end
end

[row col] = size(labels);

% INITIALIZE COLORBOXES
xx = [];
yy = [];
x = [1.1 1.9 1.9 1.1 1.1]';
y = [1.1 1.1 1.9 1.9 1.1]';
for i=0:7
        xz = x + i;
        for j=0:9
                yy = [yy (y + j)];
                xx = [xx xz];
        end
end

cla;
hold on

% COMPUTE COLORBOX POSITIONS FROM THE LABELS OF SPECTRA
% AND PAINT BOXES WITH RGB-COLORS
for i=1:row
	s = find(labels(i,:)=='V');
	v = str2num(labels(i,s+1:s+2))/10 - 1;
	c = str2num(labels(i,s+4:s+5)) - 1;
	if(abs(v - 1.5) <= eps)		% value 2.5
		v = 1;
	end
	if(v == 8)			% value 8
		v = 9;
	end
	if(abs(v - 7.5) <= eps)		% value 8.5
		v = 8;
	end
	if(c>1)
		c = c/2.0 + 0.5;
	end
	handle = fill(xx(:,v+c*10),yy(:,v+c*10),[(R(i)/100.0)^gam (G(i)/100.0)^gam (B(i)/100)^gam]);
        cb = ['figure(2);plot(400:5:700, get(gco(1),''userdata''),''w'');grid;', ...
        'set(gca,''ylim'',[0 1]);', ...
        'xlabel(''Wavelength (nm)'');ylabel(''Reflectance'');title(''',labels(i,:),''');'];
        set(handle, 'userdata', spec(:,i), 'buttondownfcn', cb);

end

% SET COORDINATE AXIS LABELS AND TICKMARKS
set(gca,'title',text(0,0,P(ind,:),'color',[0 0 0]));
set(gca,'xlabel',text(0,0,'Chroma','color',[0 0 0]));
set(gca,'ylabel',text(0,0,'Value','color',[0 0 0]));
set(gca,'XLim',[1 9],'xcolor',[0 0 0],'ycolor',[0 0 0]);
set(gca,'XTick',[1.5,2.5,3.5,4.5,5.5,6.5,7.5,8.5,9.5,10.5]);
set(gca,'XTickLabels',['/1 ';'/2 ';'/4 ';'/6 ';'/8 ';'/10';'/12';'/14';'/16']);
set(gca,'YTick',[1.5,2.5,3.5,4.5,5.5,6.5,7.5,8.5,9.5,10.5]);
set(gca,'YTickLabels',['2.5/';'  3/';'  4/';'  5/';'  6/';'  7/';'  8/';'8.5/';'  9/';'    ']);
set(gca,'title',text(0,0,P(ind,:),'color',[0 0 0]));

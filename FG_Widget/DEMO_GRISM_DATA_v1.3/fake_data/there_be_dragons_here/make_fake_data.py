import numpy
import time
import numpy.random
import scipy
import Gnuplot
import pyfits
import matplotlib.cm as cm
import matplotlib.mlab as mlab
import matplotlib.pyplot as pyplot

class Grism( object ):
    def __init__(self, name, sigma, delta, n, l_start, l_stop):
        self.name = name
        self.sigma = sigma
        self.delta = delta
        self.n = n
        self.l_start = l_start
        self.l_stop = l_stop

    def calc_beta(self, wl, m):
        beta = numpy.degrees(numpy.arcsin( m*wl/self.sigma - self.n*numpy.sin(numpy.radians(self.delta)))) + self.delta
        return beta


class Slit( object ):
    def __init__(self, length, width, PSF_FWHM):
        self.FWHM = PSF_FWHM
        self.length = length
        self.width = width
        if (length > width):
            self.orientation = 1   # Cross-Dispersed
            self.length_mult = 3.0
            self.width_mult = 3.0
        else:
            self.orientation = 0   # Single-order
            self.length_mult = 3.0
            self.width_mult = 3.0
        self.object_location = -1.0

    def point_source(self, position):
        self.object_location = position     # position along slit 0= top, 1 = bottom

    def slit_image(self, y_strength):
        x = numpy.arange(0, self.length*self.length_mult+1, 1.0)
        y = numpy.arange(0, self.width*self.width_mult+1, 1.0)
        X, Y = numpy.meshgrid(x, y)
        ptsource = mlab.bivariate_normal(X, Y, self.FWHM, self.FWHM, len(x)/2.0+(self.object_location-0.5)*self.length, len(y)/2.0)

        sky = numpy.zeros([len(y), len(x)])
        for i in numpy.arange(len(x)/2.0-self.length/2.0, len(x)/2.0+self.length/2.0, 1.0):
            for j in numpy.arange(len(y)/2.0-self.width/2.0, len(y)/2.0+self.width/2.0, 1.0):
                sky += ((numpy.random.randn(1))**2.0)*mlab.bivariate_normal(X, Y, self.FWHM, self.FWHM, i, j)

        #ptsource = mlab.bivariate_normal
        composite = numpy.round(sky) + numpy.round(ptsource*500.0*y_strength)
        return composite


plt = Gnuplot.Gnuplot()

PSF_FWHM = 2.0
slit_x = 2    # X dimension (in pixels)
slit_y = 256  # Y dimension (in pixels)

n_frames = 2

data_file = 'raw_G1_data.fits'

short_slit = Slit(slit_x, slit_y, PSF_FWHM)
short_slit.point_source(0.5).object_location

delta = 1.0

neg_x = numpy.floor((short_slit.length*short_slit.length_mult+1.0)/2.0)
pos_x = numpy.floor((short_slit.length*short_slit.length_mult+1.0)/2.0)+numpy.round((short_slit.length*short_slit.length_mult+1.0) % 2)
neg_y = numpy.floor((short_slit.width*short_slit.width_mult+1.0)/2.0)
pos_y = numpy.floor((short_slit.width*short_slit.width_mult+1.0)/2.0)+numpy.round((short_slit.width*short_slit.width_mult+1.0) % 2)
x = numpy.arange(-neg_x, 256+pos_x, delta)
y = numpy.arange(-neg_y, 256+pos_y, delta)
X, Y = numpy.meshgrid(x, y)
show_mask = scipy.where( (X >= 0) & (X < 256) & (Y >= 0) & (Y < 256))

#x_right = [159, 255, 255, 255, 255, 255, 255, 255]
#x_left = [0, 0, 0, 0, 0, 0, 0, 0]
#y_right = [233, 210, 177, 143, 110, 84, 58, 38]
#y_left = [202, 162, 127, 98, 69, 46, 20, 0]
m = [0, 1, 2, 3, 4, 5, 6, 7]
x_right = [256]
x_left = [0]
y_right = [0]
y_left = [0]
spectrum = []
outfile = 'input_G1_nod_spectrum.txt'
with open(outfile, 'w') as file:
    file.write(time.strftime("%a, %d %b %Y %H:%M:%S +0000", time.localtime()))
    file.write('\n')
for order in zip(x_right, x_left, y_right, y_left, m):
    xstart = order[1]
    xstop = order[0]
    xrange = numpy.arange(xstart, xstop)
    flux = numpy.ones(len(xrange))
    nlines = numpy.random.randint(0,30)
    print nlines
    for i in numpy.arange(nlines):
        line_strength = numpy.random.rand()
        line_center = numpy.random.rand()*(xstop-xstart)+xstart
        flux *= (1.0-line_strength*numpy.exp(-(xrange-line_center)**2.0/(2.0)))
    #a = Gnuplot.Data(xrange, flux, with_='lines')
    #plt.plot(a)
    spectrum.append(flux)
    with open(outfile, 'a') as file:
        for xpt, ypt in zip(xrange, flux):
            file.write(str(xpt)+', '+str(ypt)+', '+str(order[4])+'\n')

full_image = []

for i in numpy.arange(n_frames):
    Z = numpy.zeros([len(y), len(x)])
    background = numpy.random.poisson(lam=50, size = [len(y), len(x)])
    Z += background
    
    im = pyplot.imshow(Z[show_mask].reshape(256, 256), cmap=cm.gray, origin='lower', extent=[0, 256, 0, 256])
    pyplot.show()
    for order in zip(x_right, x_left, y_right, y_left, spectrum):
        xstart = order[1]
        xstop = order[0]
        xrange = numpy.arange(xstart, xstop)
        slope = float((order[2] - order[3]))/float((xstop-xstart))
        flux = order[4]
        for xpos, y_strength in zip(xrange, flux):
            c = [xpos, (order[3]+short_slit.width/2.0)+(xpos-min(xrange))*slope]
            print c, slope
            subimage = short_slit.slit_image(y_strength)
            xdim = len(subimage[0])
            ydim = len(subimage)
            mask = scipy.where( (X >= c[0]-(numpy.floor(xdim/2.0))) & (X < c[0]+(numpy.floor(xdim/2.0) + numpy.round(xdim % 2))) & (Y >= c[1]-(numpy.floor(ydim/2.0))) & (Y < c[1]+(numpy.floor(ydim/2.0) + numpy.round(ydim % 2))))
            Z[mask] += subimage.reshape(1, xdim*ydim)[0]
            im = pyplot.imshow(Z[show_mask].reshape(256, 256), cmap=cm.gray, origin='lower', extent=[0, 256, 0, 256])
    full_image.append(Z[show_mask].reshape(256, 256))

#im = pyplot.imshow(Z[show_mask].reshape(256, 256), cmap=cm.gray, origin='lower', extent=[0, 256, 0, 256])
#pyplot.show()

    F_I = numpy.array(full_image)
    
    hdu = pyfits.PrimaryHDU(F_I)
    hdu.writeto(data_file, clobber=True)

print Z.max()
print Z.min()

#a = Gnuplot.Data(x, Z[150], with_='lines')
#b = Gnuplot.Data(y, zip(*Z)[100], with_='lines')
#plt('set logscale y')
#plt('set yrange [1: 2000.0]')
#plt('set xrange [0:255]')
#plt.plot(a, b)
#im = pyplot.imshow(Z, cmap=cm.gray,origin='lower', extent=[0,256,0,256])
#pyplot.show()

print asdf

wl = numpy.linspace(5, 9, 101)

G1 = Grism('G1', 25.0, 6.16, 3.43, 4.9, 7.8)
G2 = Grism('G2', 87.0, 32.6, 3.43, 4.9, 7.8)
xdisp_beta = G1.calc_beta(wl, 1.0)
beta_m14 = G2.calc_beta(wl, 14.0)
beta_m15 = G2.calc_beta(wl, 15.0)
beta_m16 = G2.calc_beta(wl, 16.0)
beta_m17 = G2.calc_beta(wl, 17.0)
beta_m18 = G2.calc_beta(wl, 18.0)
beta_m19 = G2.calc_beta(wl, 19.0)
beta_m20 = G2.calc_beta(wl, 20.0)
beta_m21 = G2.calc_beta(wl, 21.0)
beta_m22 = G2.calc_beta(wl, 22.0)
beta_m23 = G2.calc_beta(wl, 23.0)

focal_length = 1.5748e5 #microns
xpos = numpy.tan(numpy.radians(xdisp_beta))*focal_length/50.0
ypos_m14 = numpy.tan(numpy.radians(beta_m14))*focal_length/50.0
ypos_m15 = numpy.tan(numpy.radians(beta_m15))*focal_length/50.0
ypos_m16 = numpy.tan(numpy.radians(beta_m16))*focal_length/50.0
ypos_m17 = numpy.tan(numpy.radians(beta_m17))*focal_length/50.0
ypos_m18 = numpy.tan(numpy.radians(beta_m18))*focal_length/50.0
ypos_m19 = numpy.tan(numpy.radians(beta_m19))*focal_length/50.0
ypos_m20 = numpy.tan(numpy.radians(beta_m20))*focal_length/50.0
ypos_m21 = numpy.tan(numpy.radians(beta_m21))*focal_length/50.0
ypos_m22 = numpy.tan(numpy.radians(beta_m22))*focal_length/50.0
ypos_m23 = numpy.tan(numpy.radians(beta_m23))*focal_length/50.0

m14 = Gnuplot.Data(xpos, ypos_m14, with_='lines')
m15 = Gnuplot.Data(xpos, ypos_m15, with_='lines')
m16 = Gnuplot.Data(xpos, ypos_m16, with_='lines')
m17 = Gnuplot.Data(xpos, ypos_m17, with_='lines')
m18 = Gnuplot.Data(xpos, ypos_m18, with_='lines')
m19 = Gnuplot.Data(xpos, ypos_m19, with_='lines')
m20 = Gnuplot.Data(xpos, ypos_m20, with_='lines')
m21 = Gnuplot.Data(xpos, ypos_m21, with_='lines')
m22 = Gnuplot.Data(xpos, ypos_m22, with_='lines')
m23 = Gnuplot.Data(xpos, ypos_m23, with_='lines')

plt('set xrange [-128:128]')
plt('set yrange [-128:128]')
plt('set xlabel "Cross-Dispersion"')
plt('set ylabel "Dispersion"')
#plt.plot(m14, m15, m16, m17, m18, m19, m20, m21, m22, m23)
print asdf

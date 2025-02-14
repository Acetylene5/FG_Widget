; NAME:
;     NAS - Version .7.0
;
; PURPOSE:
;     Data Reduction Pipeline for two position chop two position nod mode
;
; CALLING SEQUENCE:
;     Obj=Obj_new('NAS', FILELIST)
;     Structure=Obj->RUN(FILELIST)
;
; INPUTS:
;     FILELIST - Filename(s) of the fits file(s) containing data to be reduced.
;                May be a string array
;
; STRUCTURE:
;     (see drip__define)
;
; CALLED ROUTINES:
;
; SIDE EFFECTS:
;
; RESTRICTIONS:
;     various components need to be developed. Data file must specify locations
;     of bad pixel map and flat fields.
;
; PROCEDURE:
;     run the individual pipeline procedures.
;
; MODIFICATION HISTORY: (most from C2N__define.pro)
;     Written by:  Alfred Lee, Cornell University, 2001
;     Modified:   Alfred Lee, Cornell University, April, 2002
;                   Changed name to C2NON.  Adjusted drip to run without
;                   non-working components.  created RET input to allow
;                   quick viewing of results.  Switched to GET_DATA to
;                   read files to provide easier calling.
;     Modified:   Alfred Lee, CU, June 6, 2002
;                   Changed into an Object.  C2NON will now be
;                   called automatically from DRIP.
;     Modified:   Alfred Lee, CU June 18, 2002
;                   Data now saved as a structure, and is compressed
;                   by default. fixed other bugs and added two
;                   optional keywords
;     Modified:   Alfred Lee, CU June 21, 2002
;                   C2NON and C2NOFF are now simply, C2N.  takes a new CHOPPING
;                   parameter to determine whether the chop is on or off chip.
;                   MAKE_IMAGE is called accordingly.
;     Modified:   Alfred Lee, CU June 24, 2002
;                   Created RUN method to run the code as needed after a single
;                   initialization.
;     Modified:   Alfred Lee, CU, June 26, 2002
;                   put readme in class structure definition, and
;                   added information about the file and final image.
;                   Modified SAVE method to run from an external call,
;                   namely from DRIP. SAVE no longer compresses by
;                   default. Updated parameters and keywords to match
;                    changes in code.
;     Modified:   Alfred Lee, CU, July 18, 2002
;                   Enhanced error checking.
;     Modified:   Alfred Lee, CU, August 1, 2002
;                   Redesigned the pipeline architecture for better
;                   organization and DCAO compatibility.
;     Modified:   Alfred Lee, CU, September 27, 2002
;                   added _extra keyword to c2n::run
;     Modified:   Alfred Lee, CU, November 19, 2002
;                   returns correct structure
;     Rewritten: Marc Berthoud, CU, June 2004
;                Changed C2N object into a child object of the new
;                DRIP object (lots of code erased)
;     Modified:  Marc Berthoud, CU, March 2005
;                Renamed to C2N
;     Modified:  Marc Berthoud, CU, May 2006
;                Used c2n__define.pro to make new mode file c2__define.pro
;     Modified:  Casey Deen, UT/IC, July 2010
;                Used c2n__define.pro to creat new grism mode nas__define.pro

;******************************************************************************
;     RUN - Fills SELF structure pointer heap variables with proper values.
;******************************************************************************

pro nas::reduce

; clean
*self.cleaned=drip_clean(*self.data,*self.badmap,*self.header)
;nonlin
*self.linearized=drip_nonlin(*self.cleaned,*self.lincor)   ;LIN
; flat
*self.flatted=drip_flat(*self.linearized,*self.masterflat,*self.darksum)
; stack
*self.stacked=drip_stack(*self.flatted,*self.header, posdata=*self.posdata, $
                         chopsub=*self.chopsub)
if (self.gmode gt 1) THEN BEGIN
    *self.stacked=rot(*self.stacked, 90.0)
ENDIF
; undistort
;*self.undistorted=drip_undistort(*self.stacked,*self.header,*self.basehead)
*self.undistorted=*self.stacked

; EXTRACTION GOES HERE
;
*self.extracted = drip_spextract(*self.undistorted,*self.header, self.gmode)
;print,*self.extracted
;print,(*self.extracted)[*,0]
*self.allwave = (*self.extracted)[*,0]
*self.allflux = (*self.extracted)[*,1]
;drip_spextract, *self.undistorted, *self.header


; *self.extracted is a spectrum (1-D) that needs to be plotted and/or
; saved so we send it to cw_xlpot instead of display.

; ADDED *self.flatted for IMAGECORELLATION IN MERGE
;*self.merged=drip_merge(*self.undistorted,*self.flatted,*self.header)
*self.merged=*self.stacked
; coadd
if self.n gt 0 then begin
    ;*self.coadded=drip_coadd(*self.merged,*self.coadded, $
    ;                         *self.header, *self.basehead)
    ; Turn off coadding of images, coadd 1-D spectra later
    *self.coadded = *self.stacked
endif else begin
    ;*self.coadded=drip_coadd(*self.merged,*self.coadded, $
    ;                         *self.header, *self.basehead, /first)
    ; Turn off coadding of images, coadd 1-D spectra later
    *self.coadded = *self.stacked
endelse

; Automatically extract the spectrum from the reduced image
; 
; Extract preset regions and plot spectrum


; create README
self.readme=['pipeline: Nod Along Slit', $ ;info lines
  'file: ' + self.filename, $
  'final image: undistorted', $
  'order: CLEAN, NONLIN, FLAT, STACK, UNDISTORT, MERGE, COADD', $
  'notes: badmap from CLEAN, masterflat from FLAT']

print,'NAS FINISHED' ;info
end

;******************************************************************************
;     NAS__DEFINE - Define the NAS class structure.
;******************************************************************************

pro nas__define  ;structure definition

struct={nas, $
      inherits drip} ; child object of drip object
end

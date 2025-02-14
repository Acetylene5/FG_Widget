function dbcircle, ra_cen, dec_cen, radius, dis, sublist,SILENT=silent, $
                TO_J2000 = to_J2000, TO_B1950 = to_B1950
;+
; NAME:
;       DBCIRCLE
; PURPOSE:
;       Find sources in a database within specified radius of specified center
; EXPLANATION:
;       Database must include items named 'RA' and 'DEC' and must have 
;       previously been opened with DBOPEN
;
; CALLING SEQUENCE:
;       list = DBCIRCLE( ra_cen, dec_cen, [radius, dis, sublist, /SILENT] )   
;
; INPUTS:
;       RA_CEN - Right ascension of the search center in decimal HOURS, scalar
;       DEC_CEN - Declination of the search center in decimal DEGREES, scalar
;               RA_CEN and DEC_CEN should be in the same equinox as the 
;               currently opened catalog.
;
; OPTIONAL INPUT:
;       RADIUS - Radius of the search field in arc minutes, scalar.
;               DBCIRCLE prompts for RADIUS if not supplied.
;       SUBLIST - Vector giving entry numbers in currently opened database
;               to be searched.  Default is to search all entries
;
; OUTPUTS:
;     LIST - Vector giving entry numbers in the currently opened catalog
;            which have positions within the specified search circle
;            LIST is set to -1 if no sources fall within the search circle
;            !ERR is set to the number sources found.
;
; OPTIONAL OUTPUT
;       DIS -  The distance in arcminutes of each entry specified by LIST
;               to the search center (given by RA_CEN and DEC_CEN)
;
; OPTIONAL KEYWORD INPUT:
;       SILENT - If this keyword is set, then DBCIRCLE will not print the 
;               number of entries found at the terminal
;       TO_J2000 - If this keyword is set, then the entered coordinates are
;               assumed to be in equinox B1950, and will be converted to
;               J2000 before searching the database
;       TO_B1950 - If this keyword is set, then the entered coordinates are
;               assumed to be in equinox J2000, and will be converted to
;               B1950 before searching the database
;               NOTE: The user must determine on his own whether the database
;               is in B1950 or J2000 coordinates.
;
; METHOD:
;       A DBFIND search is first performed on a square area of given radius.
;       The list is the restricted to a circular area by using GCIRC to 
;       compute the distance of each object to the field center.
;
; EXAMPLE:
;       Find all Hipparcos stars within 40' of the nucleus of M33
;       (at J2000 1h 33m 50.9s 30d 39' 36.7'')
;
;       IDL> dbopen,'hipparcos'
;       IDL> list = dbcircle( ten(1,33,50.9), ten(3,39,36.7), 40)
;
; PROCEDURE CALLS:
;       BPRECESS, DBFIND(), DBEXT, DB_INFO(), GCIRC, JPRECESS
; REVISION HISTORY:
;      Written W. Landsman     STX           January 1990
;      Fixed search when crossing 0h         July 1990
;      Spiffed up code a bit     October, 1991
;      Converted to IDL V5.0   W. Landsman   September 1997
;      Leave DIS vector unchanged if no entries found W. Landsman July 1999
;-                   
 On_error,2

 if N_params() LT 2 then begin
    print,'Syntax - list = DBCIRCLE( ra, dec, radius, [ dis, sublist  '
    print,'                                 /SILENT, /TO_J2000, /TO_B1950 ] ) 
    if N_elements(sublist) GT 0 then return, sublist else return,lonarr(1)-1
 endif

 if (N_elements(ra_cen) NE 1) OR (N_elements(dec_cen) NE 1) then begin
    print, 'DBCIRCLE: ERROR - Expecting scalar RA and Dec parameters'
    if N_elements(sublist) GT 0 then return, sublist else return,lonarr(1)-1
 endif

 if N_params() LT 3 then read,'Enter search radius in arc minutes: ',radius

 if keyword_set(TO_J2000) then begin
        jprecess,ra_cen*15.,dec_cen,racen,deccen 
        racen = racen[0]/15.    &       deccen = deccen[0]
 endif else  if keyword_set(TO_B1950) then begin
        bprecess,ra_cen*15.,dec_cen,racen,deccen 
        racen = racen[0]/15.    &       deccen = deccen[0]
 endif else begin
        racen = ra_cen[0]    &  deccen = dec_cen[0]
 endelse

 size = radius/60.      ;Size of search field in degrees
 decmin = double(deccen-size) > (-90.)
 decmax = double(deccen+size) < 90.
 rasize = abs(size/(15.*cos(deccen/!RADEG))) < 24.  ;Correct for latitude effect

 if 2*rasize gt 24. then begin         ;Only need search on Dec?
      st = string(decmin) + '<dec<' + string(decmax) 
      redo = 0
 endif else begin
 rmin = double(racen-rasize)
 rmax = double(racen+rasize)

;  If minimum RA is less than 0, or maximum RA is greater than 24
;  then we must break up into two searchs

 if rmax gt 24. then begin
        redo = 1
        newrmax = rmax - 24.
        newrmin = 0.
        rmax = 24.
 endif else if rmin lt 0 then begin
        redo = 1
        newrmin = 24. + rmin
        newrmax = 24.
        rmin = 0.
 endif else redo = 0

 st = string(rmin) + '<ra<' + string(rmax) +',' + $
      string(decmin) + '<dec<' + string(decmax) 
 endelse

 if N_params() LT 5 then list = dbfind( st, /SIL ) else $
                         list = dbfind( st, sublist, /SIL )

 if redo then begin
        st = string(newrmin) + '<ra< ' + string(newrmax) + ',' + $
                string(decmin) + '<dec< ' + string(decmax)
        if N_params() LT 5 then newlist = dbfind(st,/SIL) else $ 
                  newlist = dbfind(st,sublist,/SIL)
        if !ERR GT 0 then list = [ list, newlist ]
 endif

; Use GCIRC to compute angular distance of each source to the field center

 silent = keyword_set(SILENT)
 if not silent then begin
      print,' ' & print,' '
 endif

 if max(list) GT 0 then begin                         ;Any entries found?
        dbext, list, 'RA,DEC', ra_match, dec_match
        gcirc,1, racen, deccen, ra_match, dec_match, ddis
        good = where( ddis/3600. LT size, Nfound )
        if Nfound GT 0 then begin
             dis = ddis[good]/60.
             if not silent then $
                 print, Nfound, ' entries found in ',db_info('name',0)
             return, list[good] 
        endif 
 endif 

 if not silent then $
       print,'No entries found by dbcircle in ', db_info( 'NAME',0 )
 return,lonarr(1)-1
 
 end

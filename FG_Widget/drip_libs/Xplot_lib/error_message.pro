;+
; NAME:
;    ERROR_MESSAGE
;
; PURPOSE:
;
;    The purpose of this function  is to have a device-independent
;    error messaging function. The error message is reported
;    to the user by using DIALOG_MESSAGE if widgets are
;    supported and MESSAGE otherwise.
;
; AUTHOR:
;
;   FANNING SOFTWARE CONSULTING
;   David Fanning, Ph.D.
;   1645 Sheely Drive
;   Fort Collins, CO 80526 USA
;   Phone: 970-221-0438
;   E-mail: davidf@dfanning.com
;   Coyote's Guide to IDL Programming: http://www.dfanning.com/
;
; CATEGORY:
;
;    Utility.
;
; CALLING SEQUENCE:
;
;    ok = Error_Message(the_Error_Message)
;
; INPUTS:
;
;    the_Error_Message: This is a string argument containing the error
;       message you want reported. If undefined, this variable is set
;       to the string in the !Error_State.Msg system variable.
;
; KEYWORDS:
;
;    NONAME: If this keyword is set the name of the calling routine
;       is not printed along with the message.
;
;    TRACEBACK: Setting this keyword results in an error traceback
;       being printed to standard output with the PRINT command.
;
;    In addition, any keyword appropriate for the MESSAGE or DIALOG_MESSAGE
;    routines can also be used.
;
; OUTPUTS:
;
;    Currently the only output from the function is the string "OK".
;
; RESTRICTIONS:
;
;    The "Warning" Dialog_Message dialog is used by default. Use keywords
;    /ERROR or /INFORMATION to select other dialog behaviors.
;
; EXAMPLE:
;
;    To handle an undefined variable error:
;
;    IF N_Elements(variable) EQ 0 THEN $
;       ok = Error_Message('Variable is undefined', /Traceback)
;
; MODIFICATION HISTORY:
;
;    Written by: David Fanning, 27 April 1999.
;    Added the calling routine's name in the message and NoName keyword. 31 Jan 2000. DWF.
;    Added _Extra keyword. 10 February 2000. DWF.
;    Forgot to add _Extra everywhere. Fixed for MAIN errors. 8 AUG 2000. DWF.
;    Adding call routine's name to Traceback Report. 8 AUG 2000. DWF.
;    Switched default value for Dialog_Message to "Error" from "Warning". 7 OCT 2000. DWF.
;-
;###########################################################################
;
; LICENSE
;
; This software is OSI Certified Open Source Software.
; OSI Certified is a certification mark of the Open Source Initiative.
;
; Copyright � 1999-2000 Fanning Software Consulting
;
; This software is provided "as-is", without any express or
; implied warranty. In no event will the authors be held liable
; for any damages arising from the use of this software.
;
; Permission is granted to anyone to use this software for any
; purpose, including commercial applications, and to alter it and
; redistribute it freely, subject to the following restrictions:
;
; 1. The origin of this software must not be misrepresented; you must
;    not claim you wrote the original software. If you use this software
;    in a product, an acknowledgment in the product documentation
;    would be appreciated, but is not required.
;
; 2. Altered source versions must be plainly marked as such, and must
;    not be misrepresented as being the original software.
;
; 3. This notice may not be removed or altered from any source distribution.
;
; For more information on Open Source Software, visit the Open Source
; web site: http://www.opensource.org.
;
;###########################################################################


FUNCTION ERROR_MESSAGE, theMessage, Traceback=traceback, $
   NoName=noName, _Extra=extra

On_Error, 2

   ; Check for presence and type of message.

IF N_Elements(theMessage) EQ 0 THEN theMessage = !Error_State.Msg
s = Size(theMessage)
messageType = s[s[0]+1]
IF messageType NE 7 THEN BEGIN
   Message, "The message parameter must be a string.", _Extra=extra
ENDIF

   ; Get the call stack and the calling routine's name.

Help, Calls=callStack
IF Float(!Version.Release) GE 5.2 THEN $
   callingRoutine = (StrSplit(StrCompress(callStack[1])," ", /Extract))[0] ELSE $
   callingRoutine = (Str_Sep(StrCompress(callStack[1])," "))[0]

   ; Are widgets supported? Doesn't matter in IDL 5.3 and higher.

widgetsSupported = ((!D.Flags AND 65536L) NE 0) OR Float(!Version.Release) GE 5.3
IF widgetsSupported THEN BEGIN
   IF Keyword_Set(noName) THEN answer = Dialog_Message(theMessage, _Extra=extra) ELSE BEGIN
      IF StrUpCase(callingRoutine) EQ "$MAIN$" THEN answer = Dialog_Message(theMessage, _Extra=extra) ELSE $
         answer = Dialog_Message(StrUpCase(callingRoutine) + ": " + theMessage, _Extra=extra)
   ENDELSE
ENDIF ELSE BEGIN
      Message, theMessage, /Continue, /NoPrint, /NoName, /NoPrefix, _Extra=extra
      Print, '%' + callingRoutine + ': ' + theMessage
      answer = 'OK'
ENDELSE

   ; Provide traceback information if requested.

IF Keyword_Set(traceback) THEN BEGIN
   Help, /Last_Message, Output=traceback
   Print,''
   Print, 'Traceback Report from ' + StrUpCase(callingRoutine) + ':'
   Print, ''
   FOR j=0,N_Elements(traceback)-1 DO Print, "     " + traceback[j]
ENDIF

RETURN, answer
END ; ----------------------------------------------------------------------------


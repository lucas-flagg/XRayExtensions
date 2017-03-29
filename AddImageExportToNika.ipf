#pragma rtGlobals=0		// Use modern global access method and strict wave access.
#include "NI1_Loader"

// Nika Image Export Extension v. 0.13r1
//  by Peter Beaucage (beaucage.peter@gmail.com / peterbeaucage.com)
// 
// Last Modified 3/6/2015
//
// Modifies Nika (by Jan Ilavsky) to, when saving ASCII data, also save both the original dataset and a 1D lineout produced as PNG files in the export folder.
//
// Change History:
//
//  0.14:
//	   - Added code from Kate Barteau to clean up figures for GISAXS processing, with wrapper to switch on/off.
//  0.13:
//     - Modified to use new Nika hook functions to modify panel and fix the 1D lineout saving feature.
//  0.12:
//     - Changed PNG export routine to use the Igor built-in one instead of Quicktime.  
//         This had caused Igor to complain and the extension to fail on Windows systems
//         without Quicktime/iTunes installed.
//  0.11:
//     - Initial Public Release



Menu "SAS 2D"
   "---"
   Submenu "Extensions"
   	   "Enable Image Export", PB_ImageOutputOn()
       "Disable Image Export", PB_ImageOutputOff()
       "Enable Image Cleanup", PB_ImageCleanupOn()
       "Disable Image Cleanup", PB_ImageCleanupOn()
    End
End

Function PB_ImageOutputOn()
	Variable /g root:Packages:PB_ImageOutput
	NVAR PB_ImageOutput = root:Packages:PB_ImageOutput

	PB_ImageOutput = 1
	
	Nika_Hook_ModifyMainPanel()
End

Function PB_ImageOutputOff()

	Variable /g root:Packages:PB_ImageOutput
	NVAR PB_ImageOutput = root:Packages:PB_ImageOutput

	
	PB_ImageOutput= 0

	Nika_Hook_ModifyMainPanel()

End

Function PB_ImageCleanupOn()
	Variable /g root:Packages:PB_CleanUpImage
	NVAR CleanUpImage = root:Packages:PB_CleanUpImage
 	
	CleanUpImage = 1
End

Function PB_ImageCleanupOff()
	Variable /g root:Packages:PB_CleanUpImage
	NVAR CleanUpImage = root:Packages:PB_CleanUpImage
 	
	CleanUpImage = 0

End


	
Function NI1EXT_Export2DImage()
	DoWindow /F CCDImageToConvertFig //bring the (2D) image to the front
	
	SVAR LoadedFile=root:Packages:Convert2Dto1D:FileNameToLoad
	
	SavePICT /P=Convert2Dto1DOutputPath /E=-5/B=72 /O /WIN=CCDImageToConvertFig as   LoadedFile + "_2D.png"
	
end	

Function NI1EXT_Export1DImage()
	
	SVAR LoadedFile=root:Packages:Convert2Dto1D:FileNameToLoad
	SavePICT /P=Convert2Dto1DOutputPath /E=-5 /B=72 /O /WIN=Q_ForImageSaving as LoadedFile + "_1D.png"
end


//hook into Nika code to change button text from Export ASCII to Export ASCII+Images.
Function Nika_Hook_ModifyMainPanel()
	NVAR/Z ImageOutput=root:Packages:PB_ImageOutput

	
  	if(NVAR_Exists(ImageOutput))
		if(ImageOutput == 1)
			CheckBox ExportDataOutOfIgor title="Export data as ASCII + Images?"
		else
			CheckBox ExportDataOutOfIgor title="Export data as ASCII?"			
		endif
	endif
End

//hook into Nika code to export 2D images
 Function AfterDisplayImageHook()
 
 	NVAR ImageOutput = root:Packages:PB_ImageOutput
 	NVAR ExportDataOutOfIgor=root:Packages:Convert2Dto1D:ExportDataOutOfIgor
 	NVAR CleanUpImage = root:Packages:PB_CleanUpImage
 	
 	if(CleanUpImage)
 		NI1M_DisplayMaskOnImage()
		ColorScale/C/N=Colorscale2D/A=RT/X=1.00/Y=1.00 widthPct=3,heightPct=30
		ModifyGraph noLabel(bottom)=2
		ModifyGraph tick(bottom)=3
		ModifyGraph fSize(MT_top)=12
		ModifyGraph fSize(left)=12,fSize(MT_left)=12
		//ModifyGraph width=400,height={Aspect,1.0}
 	endif

 	if(ImageOutput == 1 && ExportDataOutOfIgor == 1)
 			NI1EXT_Export2DImage()
 	endif 
End

//(1) use linear q when image output is enabled (2) reset the lineout each time the tool processes an image and (3) export the images
Function Nika_Hook_AfterDisplayLineOut(int,Qvec,Err)
	Wave int,Qvec,Err
	 
 	NVAR ImageOutput = root:Packages:PB_ImageOutput
 	NVAR ExportDataOutOfIgor=root:Packages:Convert2Dto1D:ExportDataOutOfIgor

 	if(ImageOutput == 1 && ExportDataOutOfIgor == 1)
		DoWindow Q_ForImageSaving
		Display/K=1 /W=(348,368,828,587.75) Int vs Qvec as "Q_ForImageSaving"	
		ModifyGraph log=0
		Label left "Intensity"
		Label bottom "Q vector [A\\S-1\\M]"
		Doupdate
		NI1EXT_Export1DImage()   
		DoWindow /K Q_ForImageSaving
	endif
End
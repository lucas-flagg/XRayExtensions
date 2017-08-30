#pragma rtGlobals=1		// Use modern global access method
#include "IR1_Loader"
//Irena Small-Angle Diffraction Rapid Analysis Tool
// "PeakTool"
// by Peter Beaucage
// v. 0.19b3


//new in 0.19:
//	   - made reporting of d-spacing consistent for all cases except HCPS, reported d-spacing is now the (100) regardless of morphology
//	   - added more peaks for bcc (up to 19) and fixed incorrect peak labelings, and incorrect calculation of reported d-spacing
// 	   - removed artificial limits on number of peaks (beyond the number in the database).
//	   - added more peaks for q214 (up to 18)
//new in 0.17:
//     - enabled control to limit number of peak markings to display.  The number of markings displayed is the lower of the number available or the number set in the control.  This number is specific to the selected wave.
//     - changed d-spacing display to use 2*pi, not 0.628 for higher precision (whether or not this precision is meaningful is an exercise left to the user...)
//     - corrected bug where d-spacing reported is off by an order of magnitude.
//new in 0.16:
//     - added appropriate value for chi-squared comparison.  Sanity check dialog should now be triggered only when chisq is 2x the expected value.
//	  - added morphology option "d* only" which tags only the first peak and gives d-spacing assuming that the main peak is the (100).
//     - fixed issue where data selection title area changes in size
//     - added (disabled) control to limit the number of peak markings to be displayed.  to be made functional in a future release.
//new in 0.15:
// 	   - fixed a bug where a single quote in the wave name would break the program
//	   - added the option to manually adjust the main peak position.


Menu "PB"
   "---"
   "Add Peak Tagging Tools to Plot", PF_CreatePanel()
   "Enable Peak Tagging on ALL Irena Plots", PF_GlobalTaggingOn()
   "Disable Peak Tagging on ALL Irena Plots", PF_GlobalTaggingOff()
End

Function AfterUpdateGenGraphHookFunction()
	NVAR PF_GlobalTagging = root:Packages:PeakTool:GlobalTagging
	if(PF_GlobalTagging)
		PF_CreatePanel()
	endif

end

Function PF_CreatePanel()
NewDataFolder /O/S root:Packages:PeakTool
String /G SelectedWaveName,SelectedWaveText,SelectedWavePath,SelectedWaveTraceName
Variable /G TagPeaksWithText,GlobalTagging,SetPeakPosValue,SetNumPeaksValue

NVAR PF_TagPeaksWithText = root:Packages:PeakTool:TagPeaksWithText
SVAR PF_SelectedWaveText = root:Packages:PeakTool:SelectedWaveText
NVAR PF_SetPeakPosValue = root:Packages:PeakTook:SetPeakPosValue
NVAR PF_SetNumPeaksValue = root:Packages:PeakTook:SetNumPeaksValue
	PF_SelectedWaveText = "No data selected.  Click to select."
	PF_TagPeaksWithText = 0
	PF_SetPeakPosValue = 0.02
	PF_SetNumPeaksValue = 8
DoWindow /F GeneralGraph  // /F means 'bring to front if it exists', will set a flag if the window doesn't exist.
if (V_flag == 0)
    Abort "Error: Plot Data Using Irena Before Adding Peak Tools!"
endif
ControlBar /T/W=GeneralGraph 50
TitleBox selectedData variable=root:Packages:PeakTool:SelectedWaveText;DelayUpdate
TitleBox selectedData pos={5,2},fixedsize=1,size={260,20}
Button fitMainPeak win=GeneralGraph,title="Fit Main Peak w/ Cursors",size={125,20};DelayUpdate
Button fitMainPeak pos={5,26},proc=PF_FitMainPeak
SetVariable setMainPeakPos title="Set Peak Pos (A^-1)",size={200,15},pos={140,29},proc=PF_SetPeakPositionProc;DelayUpdate
SetVariable setMainPeakPos limits={-inf,inf,0.002},value=root:Packages:PeakTool:SetPeakPosValue
SetVariable setNumOfMarkings title="# of Markings to Show",size={150,15},pos={350,29},proc=PF_SetNumPeaksProc;DelayUpdate
SetVariable setNumOfMarkings limits={0,30,1},value=root:Packages:PeakTool:SetNumPeaksValue
PopupMenu PeakPositionMarking win=GeneralGraph, title="Structure to Mark",mode=0;DelayUpdate
PopupMenu PeakPositionMarking value="none;d* only;LAM;HCP cyl;PC;BCC;q230/Ia3d;q214/I4132;O70/readmanual;---;plumbers;Pm3n;HCP sph;FCC;DD";DelayUpdate
PopupMenu PeakPositionMarking pos={275,1},proc=PF_StructureSelectProc
CheckBox ShowPositions win = GeneralGraph, pos={410,4}, title="Label Markings",variable=root:Packages:PeakTool:TagPeaksWithText,proc=PF_SetLabelPeaksProc
Button savePlot win=GeneralGraph, title="Save marked plot",size={125,20},pos={500,2};DelayUpdate
Button savePlot proc=PF_SavePlotGraphic
Button sendMarkingsToIrena title="Send Morphology to Irena",size={125,20},pos={500,26},disable=2

SetWindow GeneralGraph, hook(PFClickToSelect)=PF_GenGraph_Hook

End

Function PF_GlobalTaggingOn()
	Variable /g root:Packages:PeakTool:GlobalTagging
	NVAR PF_GlobalTagging = root:Packages:PeakTool:GlobalTagging
	
	PF_GlobalTagging = 1
End

Function PF_GlobalTaggingOff()
	Variable /g root:Packages:PeakTool:GlobalTagging
	NVAR PF_GlobalTagging = root:Packages:PeakTool:GlobalTagging
	
	PF_GlobalTagging = 0
	
End
	



Function PF_GenGraph_Hook(s)
	STRUCT WMWinHookStruct &s
	SVAR PF_SelectedWaveName = root:Packages:PeakTool:SelectedWaveName
	SVAR PF_SelectedWaveTraceName = root:Packages:PeakTool:SelectedWaveTraceName
	SVAR PF_SelectedWaveText = root:Packages:PeakTool:SelectedWaveText
	SVAR PF_SelectedWavePath = root:Packages:PeakTool:SelectedWavePath
	NVAR PF_SelectedWavePeakPos = root:Packages:PeakTool:SetPeakPosValue
	NVAR PF_SelectedWaveNumPeaks = root:Packages:PeakTool:SetNumPeaksValue
	WAVE/Z PF_SelectedWave
	
	if(s.eventCode == 5) //mouseup event
		String hitResult =  TraceFromPixel(s.mouseLoc.h,s.mouseLoc.v,"WINDOW:GeneralGraph;DELTAX:10;DELTAY:10;")
		if(strlen(hitResult) > 0)
			String targetName = StringByKey("TRACE", hitResult, ":", ";")
			targetName = ReplaceString("fit_", targetName, "") 
 			Wave/Z PF_SelectedWave = TraceNameToWaveRef("GeneralGraph",targetName)
 			PF_SelectedWaveTraceName = targetName
 			PF_SelectedWaveName =  GetWavesDataFolder(PF_SelectedWave,0)
 			PF_SelectedWavePath =  GetWavesDataFolder(PF_SelectedWave,1)
 			PF_SelectedWaveText = "Selected data: " + PF_SelectedWaveName + " Click to select."	
 			string currentfolder = GetDataFolder(1)	
 			SetDataFolder PF_SelectedWavePath
 			if(exists("PF_MainPeakPos"))
 				Variable PF_MainPeakPos
 				PF_SelectedWavePeakPos = PF_MainPeakPos
 			endif
 			 if(exists("PF_NumPeaksToTag"))
 				Variable PF_NumPeaksToTag
 				PF_SelectedWaveNumPeaks = PF_NumPeaksToTag
 			endif
 			SetDataFolder currentfolder
 			endif
	endif
	return 0
End

Function PF_ClearPeakMarkings()
	String ListOfTagNames = ""
	Variable i
	SVAR PF_SelectedWaveName = root:Packages:PeakTool:SelectedWaveName
	
	//old code to delete and recreate tag here...
	//string TagName="PF_MainPeakTag" + PF_SelectedWaveName
 	//String TagText = StringByKey("TEXT",AnnotationInfo("GeneralGraph",TagName))
	//Tag/K/N=$(TagName)
	//Tag/C/W=GeneralGraph/N=$(TagName)/L=2 $(PF_SelectedWaveName), ((pcsr(A) + pcsr(B))/2),TagText	

	
	for(i=0;i<40;i+=1)
 	ListOfTagNames = ListOfTagNames + "PF_PeakTag" + num2str(i) + "_" + ReplaceString(".",ReplaceString("'",ReplaceString("-",PF_SelectedWaveName,""),""),"") + ";"
 	endfor

 	for(i=0;i<40;i+=1)
	Tag/K/N=$(StringFromList(i,ListofTagNames))
	endfor

End

Function PF_RemoveFitWaves()
	String TraceNames = ListMatch(TraceNameList("GeneralGraph",";",7),"fit_*")
	
	variable i
	for(i = 0;i<ItemsInList(TraceNames);i+=1)
		RemoveFromGraph /W=GeneralGraph $StringFromList(i,TraceNames)
	endfor
End	


Function PF_MarkPeaks(trace , mainpeak, number, labels, spacings,tagwithtext)
	String trace, labels
	Variable number, mainpeak, tagwithtext
	Wave spacings
	
	Variable i
	String ListOfTagNames = ""
	SVAR PF_SelectedWaveName = root:Packages:PeakTool:SelectedWaveName
	SVAR PF_SelectedWaveTraceName = root:Packages:PeakTool:SelectedWaveTraceName
	string TagName="PF_MainPeakTag" + PF_SelectedWaveName
	TagName = ReplaceString("-",TagName,"")
	TagName = ReplaceString(".",TagName,"")
	TagName = ReplaceString("'",TagName,"")
	for(i=0;i<number;i+=1)
 	ListOfTagNames = ListOfTagNames + "PF_PeakTag" + num2str(i) + "_" + ReplaceString(".",ReplaceString("-",ReplaceString("'",PF_SelectedWaveName,""),""),"") + ";"
 	endfor
 	
 	
	Wave/Z CursorAWave = CsrWaveRef(A,"GeneralGraph") //TraceNameToWaveRef("GeneralGraph",trace)
	if(!WaveExists(CursorAWave))
		Abort "You must have selected data (by clicking) to mark."
	endif	
	Wave CursorAXWave= CsrXWaveRef(A,"GeneralGraph")  //XWaveRefFromTrace("GeneralGraph",trace)
	String CursorAWaveName = trace
	
	For(i=0;i<number;i+=1)
		FindLevel /Q CursorAXWave, spacings(i)*mainpeak
		if(tagwithtext) 
		//Print StringFromList(i,ListofTagNames)
		Tag/C/N=$(StringFromList(i,ListofTagNames))/F=0/Z=1/I=1/X=0.00/Y=(5+3*mod(i,3))/L=1 $PF_SelectedWaveTraceName, V_LevelX, "\Z08"+StringFromList(i,labels)+"q*"
		else
		Tag/C/N=$(StringFromList(i,ListofTagNames))/F=0/Z=1/I=1/X=0.00/Y=6/L=1 $PF_SelectedWaveTraceName, V_LevelX
		endif
	endfor
End



Function PF_RedrawPeakTags()
	
			string currentfolder = GetDataFolder(1)
			SVAR PF_SelectedWaveName = root:Packages:PeakTool:SelectedWaveName
			SVAR PF_SelectedWavePath = root:Packages:PeakTool:SelectedWavePath
			SVAR PF_SelectedWaveTraceName = root:Packages:PeakTool:SelectedWaveTraceName
			SVAR DataFolderList = root:Packages:GeneralplottingTool:ListOfDataFolderNames
			SetDataFolder PF_SelectedWavePath
			
			String /G PF_SelectedMorphology
			Variable /G PF_MainPeakPos
			Variable /G PF_MainPeakFWHM
			Variable /G PF_NumPeaksToTag
			Variable /G PF_TagPeaksWithText
			Variable i
			Variable numPeaks
			String ListOfLabels = ""
			if(PF_MainPeakPos == 0)
				Abort "Error: Main Peak Position Not Set!  Fit main peak before attempting to tag further peaks!"
			endif
			//Print popStr + ", popNum = " + num2str(popNum)
			PF_ClearPeakMarkings()
			string TagName="PF_MainPeakTag" + PF_SelectedWaveName
			string TagText = "\Z12 Main Peak pos= "+num2str(PF_MainPeakPos)+"A\S-1\M \Z12 FWHM = " + num2str(2*sqrt(ln(2))*PF_MainPeakFWHM)+"A\S-1\M \r"
			TagName = ReplaceString("-",TagName,"")
			TagName = ReplaceString(".",TagName,"")
			TagName = ReplaceString("'",TagName,"")		
			strswitch (PF_SelectedMorphology)
			case "none":
				ListOfLabels = ""
				Make/O Spacings = {1}
				numPeaks = 0
				break
			case "d* only":
				ListOfLabels = "1"
				Make/O Spacings = {1}
				numPeaks = 1
				TagText += "\Z12Indicated main peak gives d*= " + num2str(0.2*pi/(PF_MainPeakPos)) + " nm."
				break
			case "LAM":
				ListOfLabels="1;2;3;4;5;6;7;8;9;10;11;12;13;14;15;16;17;18;19;20"
				Make/O Spacings = {1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20}
				numPeaks = 20
				//PF_MarkPeaks(PF_SelectedWaveName,PF_MainPeakPos,numPeaks,ListOfLabels,Spacings)
				//TextBox/C/N=PF_PositionLabel "\Z12Peak markings correspond to expected positions \rfor lamellar structure with d= " + num2str(0.2*pi/PF_MainPeakPos) + " nm."
				TagText += "\Z12Peak markings correspond to expected positions \rfor lamellar structure with d\B100\M\Z12= " + num2str(0.2*pi/PF_MainPeakPos) + " nm."
				break
			case "HCP cyl":
				ListOfLabels="1;Ã3;2;Ã7;3;Ã12;Ã13;4;Ã19;Ã21;5;Ã27;Ã28;Ã31;6;Ã37;Ã39;Ã43;Ã48;7"
				Make/O Spacings = {1,sqrt(3),2,sqrt(7),3,sqrt(12),sqrt(13),4,sqrt(19),sqrt(21),5,sqrt(27),sqrt(28),sqrt(31),6,sqrt(37),sqrt(39),sqrt(43),sqrt(48),7}
				numPeaks = 20
				//PF_MarkPeaks(PF_SelectedWaveName,8,ListOfLabels,Spacings)
				TagText +=   "\Z12Peak markings correspond to expected positions \rfor HCP cylinders structure with d\B100\M\Z12= " + num2str(0.2*pi/PF_MainPeakPos) + " nm."

				break
			case "PC":
				ListOfLabels="1;Ã2;Ã3;2;Ã5;Ã6;Ã8;3"
				Make/O Spacings = {1,sqrt(2),sqrt(3),2,sqrt(5),sqrt(6),sqrt(8),3}
				numPeaks = 8
				//PF_MarkPeaks(PF_SelectedWaveName,8,ListOfLabels,Spacings)
				TagText +=  "\Z12Peak markings correspond to expected positions \rfor simple cubic structure with d\B100\M\Z12= " + num2str(0.2*pi/PF_MainPeakPos) + " nm."

				break
			case "BCC":
				ListOfLabels="Ã2;2;Ã6;Ã8;Ã10;Ã12;Ã14;Ã16;Ã18;Ã20;Ã22;Ã24;Ã26;Ã30;Ã32;Ã34;Ã38;Ã40;Ã42"
				Make/O Spacings = {sqrt(2)/sqrt(2),2/sqrt(2),sqrt(6)/sqrt(2),sqrt(8)/sqrt(2),sqrt(10)/sqrt(2),sqrt(12)/sqrt(2),sqrt(14)/sqrt(2),sqrt(16)/sqrt(2),sqrt(18)/sqrt(2),sqrt(20)/sqrt(2),sqrt(22)/sqrt(2),sqrt(24)/sqrt(2),sqrt(26)/sqrt(2),sqrt(30)/sqrt(2),sqrt(32)/sqrt(2),sqrt(34)/sqrt(2),sqrt(38)/sqrt(2),sqrt(40)/sqrt(2),sqrt(42)/sqrt(2)}
				numPeaks = 19				
				TagText +=  "\Z12Peak markings correspond to expected positions \rfor BCC structure with d\B100\M\Z12= " + num2str(sqrt(2)*0.2*pi/PF_MainPeakPos) + " nm."

				break
			case "FCC":
				ListOfLabels="Ã3;2;Ã8;Ã11;Ã12;4;Ã19"
				Make/O Spacings = {1,2/sqrt(3),sqrt(8)/sqrt(3),sqrt(11)/sqrt(3),sqrt(12)/sqrt(3),4/sqrt(3),sqrt(19)/sqrt(3)}
				
				numPeaks = 7
				TagText += "\Z12Peak markings correspond to expected positions \rfor FCC structure with d\B100\M\Z12= " + num2str(0.2*pi/PF_MainPeakPos) + " nm."

				break		
			case "HCP sph":
				ListOfLabels="Ã32;6;Ã41;Ã68;Ã96;Ã113"
				Make/O Spacings = {1,6/sqrt(32),sqrt(41)/sqrt(32),sqrt(68)/sqrt(32),sqrt(96)/sqrt(32),sqrt(113)/sqrt(32)}
				
				numPeaks = 6
				TagText += "\Z12Peak markings correspond to expected positions \rfor HCP sphere structure with d*= " + num2str(0.2*pi/PF_MainPeakPos) + " nm."

				break	
			case "DD":
				ListOfLabels="Ã2;Ã3;2;Ã6;Ã8;3;Ã10;Ã11"
				Make/O Spacings = {1,sqrt(3)/sqrt(2),2/sqrt(2),sqrt(6)/sqrt(2),sqrt(8)/sqrt(2),3/sqrt(2),sqrt(10)/sqrt(2),sqrt(11)/sqrt(2)}
				
				numPeaks = 8
				TagText += "\Z12Peak markings correspond to expected positions \rfor double diamond structure with d\B100\M\Z12= " + num2str(sqrt(2)*0.2*pi/PF_MainPeakPos) + " nm."

				break						
			case "q230/Ia3d":
				ListOfLabels="Ã3;2;Ã7;Ã8;Ã10;Ã11;Ã12"
				Make/O Spacings = {1,2/sqrt(3),sqrt(7)/sqrt(3),sqrt(8)/sqrt(3),sqrt(10)/sqrt(3),sqrt(11)/sqrt(3),sqrt(12)/sqrt(3)}
				
				numPeaks = 7
				TagText += "\Z12Peak markings correspond to expected positions \rfor Q230/ia3d structure with d\B100\M\Z12= " + num2str(sqrt(3)*0.2*pi/PF_MainPeakPos) + " nm."

				break					
			case "Pm3n":
				ListOfLabels="Ã2;2;Ã5;Ã6;Ã8;Ã10;Ã12"
				Make/O Spacings = {1,2/sqrt(2),sqrt(5)/sqrt(2),sqrt(6)/sqrt(2),sqrt(8)/sqrt(2),sqrt(10)/sqrt(2),sqrt(12)/sqrt(2)}
				
				numPeaks = 7
				TagText += "\Z12Peak markings correspond to expected positions \rfor Pm3n structure with d\B100\M\Z12= " + num2str(sqrt(2)*0.2*pi/(PF_MainPeakPos)) + " nm."

				break	
			case "q214/I4132":
				ListOfLabels="Ã2;Ã6;Ã8;Ã10;Ã12;Ã14;Ã16;Ã18;Ã20;Ã22;Ã24;Ã26;Ã30;Ã32;Ã34;Ã36;Ã38;Ã40;Ã42;Ã44;Ã46;Ã48;Ã50;Ã52;Ã54;Ã56;Ã58"
				Make/O Spacings = {1,sqrt(6)/sqrt(2),sqrt(8)/sqrt(2),sqrt(10)/sqrt(2),sqrt(12)/sqrt(2),sqrt(14)/sqrt(2),sqrt(16)/sqrt(2),sqrt(18)/sqrt(2),sqrt(20)/sqrt(2),sqrt(22)/sqrt(2),sqrt(24)/sqrt(2),sqrt(26)/sqrt(2),sqrt(30)/sqrt(2),sqrt(32)/sqrt(2),sqrt(34)/sqrt(2),sqrt(36)/sqrt(2),sqrt(38)/sqrt(2),sqrt(40)/sqrt(2),sqrt(42)/sqrt(2),sqrt(44)/sqrt(2),sqrt(46)/sqrt(2),sqrt(48)/sqrt(2),sqrt(50)/sqrt(2),sqrt(52)/sqrt(2),sqrt(54)/sqrt(2),sqrt(56)/sqrt(2),sqrt(58)/sqrt(2)}
				
				numPeaks = 27
				TagText += "\Z12Peak markings correspond to expected positions \rfor q214 structure with d\B100\M\Z12= " + num2str(sqrt(2)*0.2*pi/(PF_MainPeakPos)) + " nm."

				break					
			case "O70/readmanual":
				// This uses the a/c and b/c ratios from Chatterjee, Jain, and Bates Macromolecules 40 (2007) observed in the poly(isoprene-b-styrene-b-ethylene oxide) ISO system.
				//a/c ) 0.280, b/c ) 0.554, 
				//. The allowed Miller indices for the Fddd space group are 004, 111, 022, 113, 115, 131, 026, 133, 040, 202, 220, and 222
				ListOfLabels="(004);(111);(022);(113);(115);(131);(026);(133);(040);(202);(220);(222)"
				Variable abyc = 0.280
				Variable bbyc = 0.554
				Make/O Spacings = {1,(1/2)*sqrt(1*abyc+1*bbyc+1),(1/2)*sqrt(0*abyc+2*bbyc+2),(1/2)*sqrt(1*abyc+1*bbyc+3),(1/2)*sqrt(1*abyc+1*bbyc+5),(1/2)*sqrt(1*abyc+3*bbyc+1),(1/2)*sqrt(0*abyc+2*bbyc+6),(1/2)*sqrt(1*abyc+3*bbyc+3),(1/2)*sqrt(0*abyc+4*bbyc+0),(1/2)*sqrt(2*abyc+0*bbyc+2),(1/2)*sqrt(2*abyc+2*bbyc+0),(1/2)*sqrt(2*abyc+2*bbyc+2)}
				
				numPeaks = 12
				TagText += "\Z12Peak markings correspond to expected positions \rfor O70 structure with c= " + num2str(sqrt(2)*0.2*pi/(PF_MainPeakPos)) + " nm, a/c = 0.280, b/c = 0.554."

				break															
			endswitch
			
			if(PF_NumPeaksToTag < numPeaks)
				numPeaks = PF_NumPeaksToTag
			endif
			PF_MarkPeaks(PF_SelectedWaveTraceName,PF_MainPeakPos,numPeaks,ListOfLabels,Spacings,PF_TagPeaksWithText)
			ReplaceText/N=$(TagName)/W=GeneralGraph TagText	
			SetDataFolder currentfolder
			PF_RemoveFitWaves()

End

Function PF_FitMainPeak(ba) : ButtonControl
	STRUCT WMButtonAction &ba
	SVAR PF_SelectedWaveName = root:Packages:PeakTool:SelectedWaveName
	SVAR PF_SelectedWavePath = root:Packages:PeakTool:SelectedWavePath
	SVAR PF_SelectedWaveTraceName = root:Packages:PeakTool:SelectedWaveTraceName
	WAVE PF_SelectedWave = root:Packages:PeakTool:SelectedWave
	NVAR PF_SelectedWavePeakPos = root:Packages:PeakTool:SetPeakPosValue
	string currentfolder = GetDataFolder(1)
				
	switch( ba.eventCode )
		case 2: // mouse up
				//check that cursors are set and set on the same wave or give error - modified from Irena basic peak fitting routine
		
				Wave/Z CursorAWave = CsrWaveRef(A, "GeneralGraph")
				Wave/Z CursorBWave = CsrWaveRef(B, "GeneralGraph")
	if(!WaveExists(CursorAWave) || !WaveExists(CursorBWave) || cmpstr(NameOfWave(CursorAWave),NameOfWave(CursorBWave))!=0)
		Abort "The cursors are not set properly - they are not in the graph or not on the same data"
	endif
	if(cmpstr(GetWavesDataFolder(CursorAWave,0),PF_SelectedWaveName)!= 0)
		Abort "Cursors are not on the currently selected wave. Place cursors on fit range."
	endif
	
	Wave CursorAXWave= CsrXWaveRef(A, "GeneralGraph")
	string TagName="PF_MainPeakTag" + PF_SelectedWaveName
	Print TagName
		TagName = ReplaceString("-",TagName,"")
	TagName = ReplaceString(".",TagName,"")
	TagName = ReplaceString("'",TagName,"")
	string TagText

	Wave/Z  FitWave= $("fit_"+NameOfWave(CursorAWave))
	KillWaves/Z FitWave
	string FitWaveName= UniqueName("PF_FitWave",1,0)
	Wave/Z  FitXWave= $("fitX_"+NameOfWave(CursorAWave))
	KillWaves/Z FitXWave
	string FitXWaveName= UniqueName("PF_FitWaveX",1,0)
	
	Make/D/N=0/O W_coef, LocalEwave
	Make/D/T/N=0/O T_Constraints
	Wave/Z W_sigma
	//find the error wave and make it available, if exists
	Wave/Z ErrorWave=$(IR1P_FindErrorWaveForCursor())
	Variable V_FitError=0			//This should prevent errors from being generated
	
		if (WaveExists(ErrorWave))
			CurveFit gauss CursorAWave[pcsr(A),pcsr(B)] /X=CursorAXWave /D /W=ErrorWave /I=1
		else
			CurveFit gauss CursorAWave[pcsr(A),pcsr(B)] /X=CursorAXWave /D		
		endif
			
		TagText = "\Z12 Main Peak \r pos= "+num2str(W_coef[2])+"A\S-1\M \Z12  \r FWHM = " + num2str(2*sqrt(ln(2))*W_coef[3])+"A\S-1\M \Z12  chi\S2\M = "+num2str(V_chisq)
		Tag/C/W=GeneralGraph/N=$(TagName)/L=2 $PF_SelectedWaveTraceName, ((pcsr(A) + pcsr(B))/2),TagText	
		
		//SVAR DataFolderList = root:Packages:GeneralplottingTool:ListOfDataFolderNames
		//SetDataFolder ReplaceString(PF_SelectedWaveName,ReplaceString(";",ListMatch(DataFolderList,"*"+PF_SelectedWaveName+"*"),""),"") 
		//SetDataFolder GetWavesDataFolder(ListMatch(DataFolderList,"*"+PF_SelectedWaveName+"*"),1)
		SetDataFolder PF_SelectedWavePath
		Variable /G PF_MainPeakPos = W_coef[2]
		Variable /G PF_MainPeakFWHM = 2*sqrt(ln(2))*W_coef[3]
		
		PF_SelectedWavePeakPos = W_coef[2]
		SetDataFolder currentfolder		
		if(V_chisq>	2*(str2num(StringByKey("POINT",CsrInfo(B))) - str2num(StringByKey("POINT",CsrInfo(A)))) ) //number of points in fit
		Abort "Note: Chi-Square seems to be quite high.  Try zooming in to verify good fit to first peak"
		endif

			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

Function PF_SavePlotGraphic(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up

			SavePICT/E=-5/TRAN=1/B=144
						
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

Function PF_StructureSelectProc(pa) : PopupMenuControl
	STRUCT WMPopupAction &pa

	switch( pa.eventCode )
		case 2: // mouse up
		
			Variable popNum = pa.popNum
			String popStr = pa.popStr
			
			string currentfolder = GetDataFolder(1)
			SVAR PF_SelectedWaveName = root:Packages:PeakTool:SelectedWaveName
			SVAR PF_SelectedWavePath = root:Packages:PeakTool:SelectedWavePath
			SVAR PF_SelectedWaveTraceName = root:Packages:PeakTool:SelectedWaveTraceName
			SVAR DataFolderList = root:Packages:GeneralplottingTool:ListOfDataFolderNames
			SetDataFolder PF_SelectedWavePath
			
			String /G PF_SelectedMorphology = popStr
			Variable /G PF_NumPeaksToTag = 6
			
			SetDataFolder currentfolder
			
			PF_RedrawPeakTags()
			
		case -1: // control being killed
			break
	endswitch

	return 0
End

Function  PF_SetPeakPositionProc(sva) : SetVariableControl
	STRUCT WMSetVariableAction &sva

	switch( sva.eventCode )
		case 1: // mouse up
		case 2: // Enter key
		case 3: // Live update
			Variable dval = sva.dval
			String currentfolder = GetDataFolder(1)
			SVAR PF_SelectedWavePath = root:Packages:PeakTool:SelectedWavePath
			
			SetDataFolder PF_SelectedWavePath
			Variable /G PF_MainPeakPos = sva.dval
			SetDataFolder currentfolder		
			
			PF_RedrawPeakTags()
			
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End
Function PF_SetNumPeaksProc(sva) : SetVariableControl
	STRUCT WMSetVariableAction &sva

	switch( sva.eventCode )
		case 1: // mouse up
		case 2: // Enter key
		case 3: // Live update
			Variable dval = sva.dval
			String currentfolder = GetDataFolder(1)
			SVAR PF_SelectedWavePath = root:Packages:PeakTool:SelectedWavePath
	
			SetDataFolder PF_SelectedWavePath
			Variable /G PF_NumPeaksToTag = sva.dval
			SetDataFolder currentfolder		
			
			PF_RedrawPeakTags()
			
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End
Function PF_SetLabelPeaksProc (ctrlName,checked) : CheckBoxControl
	String ctrlName
	Variable checked
	String currentfolder = GetDataFolder(1)
	SVAR PF_SelectedWavePath = root:Packages:PeakTool:SelectedWavePath
			
			SetDataFolder PF_SelectedWavePath
			Variable /G PF_TagPeaksWithText = checked
			SetDataFolder currentfolder		
	PF_RedrawPeakTags()
	
End

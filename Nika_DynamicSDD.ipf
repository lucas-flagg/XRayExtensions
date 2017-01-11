#pragma rtGlobals=3		// Use modern global access method and strict wave access.
#include "NI1_Loader"

//Nika dynamic reduction parameter support v. 0.1
// by Peter Beaucage and Robert Bell
//  Cornell University


Menu "SAS 2D"
	Submenu "Extensions"
		"---"
		"Dynamic Reduction Parameter Tool", NI1_DSDD_ConfigPanel()
	End
End

Window NI1_DSDD_ConfigPanel() : Panel
	PauseUpdate; Silent 1		// building window...
	
	NewPanel /K=1
	String OldDf = GetDataFolder(1)
	
	if(DataFolderExists("root:Packages:NikaDynamicSDD"))
		SetDataFolder("root:Packages:NikaDynamicSDD")
	else
		NewDataFolder /O /S root:Packages:NikaDynamicSDD
		Variable /G SelectedMode=1
		Variable /G UseFixedStart=0
		Variable /G Start_BCX=1
		Variable /G Start_BCY=1
		Variable /G Start_SDD=500
		Variable /G LinFit_SDDA=0
		Variable /G LinFit_SDDB=0
		String /G LinFit_XParameter="PointNumber"
	endif
	
	TitleBox NI1_DSDD_Title,pos={93,2},size={92,20},title="Dynamic SDD Tools"
	CheckBox NI1_DSDD_Disable,pos={15,30},size={114,15},title="Use Static Parameters"
	CheckBox NI1_DSDD_Disable,value= 0,mode=1,proc=NI1_DSDD_ChangeDSDDMode
	CheckBox NI1_DSDD_RefitEveryTime,pos={15,50},size={160,15},title="Fit parameters to every data set"
	CheckBox NI1_DSDD_RefitEveryTime,value= 0,mode=1,proc=NI1_DSDD_ChangeDSDDMode
	CheckBox NI1_DSDD_UseFunction,pos={15,137},size={234,15},title="Use static beam center + linear function for SDD?"
	CheckBox NI1_DSDD_UseFunction,value= 0,mode=1	,proc=NI1_DSDD_ChangeDSDDMode
	
	Button NI1_DSDD_ConfigureBC title="Setup Fit",pos={200,50},size={75,20},proc=NI1_DSDD_OpenRefinementPanel
	CheckBox NI1_DSDD_ResetParams,pos={45,70},size={147,15},title="Use fixed starting conditions?"
	CheckBox NI1_DSDD_ResetParams,value= 0,variable=UseFixedStart,proc=NI1_DSDD_ChangeDSDDMode
	SetVariable NI1_DSDD_ResetBCYTo,pos={66,102},size={150,15},title="Beam Center Y",value=Start_BCY
	SetVariable NI1_DSDD_ResetBCXTo,pos={66,85},size={150,15},title="Beam Center X",value=Start_BCX
	SetVariable NI1_DSDD_ResetSDDTo,pos={66,117},size={150,15},title="Sam.-Det. Dist.",value=Start_SDD

	SetVariable NI1_DSDD_SDDA,pos={38,156},size={100,15},title="SDD = ",value=LinFit_SDDA
	SetVariable NI1_DSDD_SDDB,pos={135,156},size={125,15},title="* (x) + ",value=LinFit_SDDB
	SetVariable NI1_DSDD_SDDX,pos={45,175},size={200,15},title="where x is in wavenote under",value=LinFit_XParameter,limits={-inf,inf,0}
	
	NI1_DSDD_ChangeDSDDMode("",1)
	SetDataFolder(OldDf)
EndMacro

Function NI1_DSDD_ChangeDSDDMode(name,value)
	String name
	Variable value
	
	NVAR gRadioVal= root:Packages:NikaDynamicSDD:SelectedMode
	NVAR ResetEveryTime = root:Packages:NikaDynamicSDD:UseFixedStart
	
	strswitch (name)
		case "NI1_DSDD_Disable":
			gRadioVal= 1
			break
		case "NI1_DSDD_RefitEveryTime":
			gRadioVal= 2
			Button NI1_DSDD_ConfigureBC,disable=0
			CheckBox NI1_DSDD_ResetParams,disable=0
			break
		case "NI1_DSDD_UseFunction":
			gRadioVal= 3
			SetVariable NI1_DSDD_SDDA,disable=0
			SetVariable NI1_DSDD_SDDB,disable=0
			SetVariable NI1_DSDD_SDDX,disable=0
			break
	endswitch
	CheckBox NI1_DSDD_Disable,value= gRadioVal==1
	CheckBox NI1_DSDD_RefitEveryTime,value= gRadioVal==2
	CheckBox NI1_DSDD_UseFunction,value= gRadioVal==3
	
	if(gRadioVal != 2)
		Button NI1_DSDD_ConfigureBC,disable=2
		CheckBox NI1_DSDD_ResetParams,disable=2
		SetVariable NI1_DSDD_ResetBCYTo,disable=2
		SetVariable NI1_DSDD_ResetBCXTo,disable=2
		SetVariable NI1_DSDD_ResetSDDTo,disable=2
	endif
	if(gRadioVal != 3)
		SetVariable NI1_DSDD_SDDA,disable=2
		SetVariable NI1_DSDD_SDDB,disable=2
		SetVariable NI1_DSDD_SDDX,disable=2
	endif
	if(ResetEveryTime && gRadioVal==2)
		SetVariable NI1_DSDD_ResetBCYTo,disable=0
		SetVariable NI1_DSDD_ResetBCXTo,disable=0
		SetVariable NI1_DSDD_ResetSDDTo,disable=0
	else
		SetVariable NI1_DSDD_ResetBCYTo,disable=2
		SetVariable NI1_DSDD_ResetBCXTo,disable=2
		SetVariable NI1_DSDD_ResetSDDTo,disable=2
	endif
End
Function NI1_DSDD_OpenRefinementPanel(ctrlName) : ButtonControl
	String ctrlName

	NI1_CreateBmCntrFile()
	TabControl BmCntrTab value=2
	NI1BC_TabProc("BmCntrTab",2)
End


Function NI1_BeforeConvertDataHook()
	NVAR mode = root:Packages:NikaDynamicSDD:SelectedMode
	NVAR setBCXto = root:Packages:NikaDynamicSDD:Start_BCX
	NVAR setBCYto = root:Packages:NikaDynamicSDD:Start_BCY
	NVAR setSDDto = root:Packages:NikaDynamicSDD:Start_SDD
	NVAR useFixedStart = root:Packages:NikaDynamicSDD:UseFixedStart

	switch(mode)
		case 1:
			break
		case 2:
			//do refitting with parameters
			print "using dynamic SDD re-fitting"
			if(useFixedStart)
				NVAR BeamCenterX=root:Packages:Convert2Dto1D:BeamCenterX
				NVAR BeamCenterY=root:Packages:Convert2Dto1D:BeamCenterY
				NVAR SampleToCCDDistance=root:Packages:Convert2Dto1D:SampleToCCDDistance
		
				BeamCenterX= setBCXto
				BeamCenterY= setBCYto 
				SampleToCCDDistance= setSDDto
			endif
					
			Wave convertImageBob=root:Packages:Convert2Dto1D:CCDImageToConvert
			Wave beamCenterImageBob=root:Packages:Convert2Dto1D:BmCntrCCDImg
			beamCenterImageBob=convertImageBob
			
			NI1BC_RunRefinement()
			NI1BC_RunRefinement()
			break
		case 3:
			//set SDD to output of linear function
			NVAR SampleToCCDDistance=root:Packages:Convert2Dto1D:SampleToCCDDistance
			NVAR LinFitA = root:Packages:NikaDynamicSDD:LinFit_SDDA
			NVAR LinFitB = root:Packages:NikaDynamicSDD:LinFit_SDDB
			SVAR xname = root:Packages:NikaDynamicSDD:LinFit_XParameter
			Wave convertImageBob=root:Packages:Convert2Dto1D:CCDImageToConvert
			Variable xcoord = str2num(StringByKey(xname,note(convertImageBob),"="))
			print "using dynamic SDD linear function: SDD = " + num2str(LinFitA) + " * " + xname + " + " + num2str(LinFitB) + "   where " + xname + " = " + num2str(xcoord)
			SampleToCCDDistance = LinFitA * xcoord + LinFitB
			break
	endswitch
End


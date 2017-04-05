#pragma rtGlobals=1		// Use modern global access method

//  Nika support module for reading spec metadata for images taken at the Cornell High Energy Synchrotron Source beamline G1 (Materials/Bio SAXS)
//		and, more generally, for spec metadata for any detector driven using the CHESS spec/EPICS/AreaDetector linkage by Zak Brown, Arthur Woll, et al.
//      v. 0.8b1
//      by Peter Beaucage (pab275@cornell.edu)
//
//		Change Log:
//		v 0.8:
//			- Modified filename parsing to be more robust toward filenames with underscores in them, hopefully.
//		v. 0.7:
//			- Added support for JR's Pilatus macros which use yet another file maning convention.  Should now (probably) support data taken at A2.
//		v. 0.6:
//			- Added support for converted tif images taken by the Detector Pool EIGER 1M.
//			- Corrected an error where a motor could appear twice with two different positions, one from the scan header (inaccurate) and one from the point header (accurate).		
//			- Rewrote the code for handling scan headers, should now be much more robust toward motor names with spaces in them eg "slit 1 height".
//		v. 0.5:
//			- Added support for metadata fetching from ADSC and ADSC_A format images taken at A1 during Fall 2015 cycle.
//			- Added further redundancy for multiple spaces between spec headings.  Note that spaces in spec motor names, etc are still a major pain and may not work correctly
//			  in all cases.  It’s further possible that spaces could cause other metadata to be corrupted / off-by-1.  If values seem unreasonable, send me the test case.
// 	v. 0.4:
//			- Added support for data taken during Fall 2015 run cycle with any CHESS-configured Pilatus detector (tested only with PIL5, Pilatus3-300K-500Hz)
//			- Added caching mechanism, stores metadata in wavenote reducing amount of time taken to process data set substantially.
//			- Added option (recommended for runs using the new CHESS DAQ configuration beginning Spring-Summer 2015) to load metadata from same folder as data.
//
//	
// Useful user functions defined by this code are:
//
//	CHESSG1_GetSampleI0(ImageFileName)
//	CHESSG1_GetDiode(ImageFileName)
//	CHESSG1_GetTransmission(ImageFileName)
//	CHESSG1_GetCountTime(ImageFileName)
//	CHESSG1_GetEmptyCountTime(ImageFileName)
//	CHESSG1_GetEmptyI0(ImageFileName)
//	CHESSG1_GetEmptyDiode(ImageFileName)
// 		(which are all hopefully self-explanatory)
//and the general purpose loader functions:
//	CHESSG1_GetSampleMetadata(ParameterName)
//	CHESSG1_GetEmptyMetadata(ParameterName)
//which return the value spec has for any parameter you can name.  for example, if you want to get the sample stage x-position for the active data set, simply do:
//	CHESSG1_GetSampleMetadata("gamx")
//
//note that in all cases, the ImageFileName parameter is ignored.  It is necessary due to a quirk of Nika.
//

Menu "SAS 2D"
	Submenu "Instrument configurations"
		"CHESS Metadata", CHESSG1_ParameterPanel()
	End
End



//"core" functions that access specific data:
function CHESSG1_GetSampleI0(ImageFileName)
	String ImageFileName
	SVAR VarName=root:Packages:Convert2Dto1D:CHESSG1i0
	NVAR Gain=root:Packages:Convert2Dto1D:CHESSG1i0gain
	return 10^gain*CHESSG1_GetSampleMetadata(VarName)
end

function CHESSG1_GetDiode(ImageFileName)
	String ImageFileName
	SVAR DiodeVarName = root:Packages:Convert2Dto1D:CHESSG1diode
	NVAR DiodeGain=root:Packages:Convert2Dto1D:CHESSG1diodegain
	return 10^diodegain*CHESSG1_GetSampleMetadata(DiodeVarName)
end

function CHESSG1_GetCountTime(ImageFileName)
	String ImageFileName
	SVAR VarName=root:Packages:Convert2Dto1D:CHESSG1time
	return CHESSG1_GetSampleMetadata(VarName)
end

//transmission
function CHESSG1_GetSampleTransmission(ImageFileName)
	String ImageFileName
	return CHESSG1_GetTransmission(ImageFileName)
end

function CHESSG1_GetTransmission(ImageFileName)
	String ImageFileName
	wave/Z CCDImageToConvert = root:Packages:Convert2Dto1D:CCDImageToConvert
	wave/Z EmptyData = root:Packages:Convert2Dto1D:EmptyData
	variable transmission
	if(!WaveExists(CCDImageToConvert) || !WaveExists(EmptyData))
		abort "Sample transmission requires both sample and empty data.  Check that an empty is selected."
	endif
	transmission = (CHESSG1_GetDiode(ImageFileName)/CHESSG1_GetSampleI0(ImageFileName)/(CHESSG1_GetEmptyDiode(ImageFileName)/CHESSG1_GetEmptyI0(ImageFileName)))
	print("Measured sample transmission of " + num2str(transmission))
	return transmission
end



function CHESSG1_GetEmptyCountTime(ImageFileName)
	String ImageFileName
	SVAR VarName=root:Packages:Convert2Dto1D:CHESSG1time
	return CHESSG1_GetEmptyMetadata(VarName)
end

function CHESSG1_GetEmptyI0(ImageFileName)
	String ImageFileName
	SVAR VarName=root:Packages:Convert2Dto1D:CHESSG1i0
	NVAR Gain=root:Packages:Convert2Dto1D:CHESSG1i0gain
	return 10^gain*CHESSG1_GetEmptyMetadata(VarName)
end

function CHESSG1_GetEmptyDiode(ImageFileName)
	String ImageFileName
	SVAR DiodeVarName = root:Packages:Convert2Dto1D:CHESSG1diode
	NVAR DiodeGain=root:Packages:Convert2Dto1D:CHESSG1diodegain
	return 10^diodegain*CHESSG1_GetEmptyMetadata(DiodeVarName)
end

//underlying lookup functions.  If metadata has already been loaded, they just reference the wavenote (fast!).  Otherwise, they load it in (less fast!)
function CHESSG1_GetSampleMetadata(valueToLoad)
	string valueToLoad
	wave/Z CCDImageToConvert = root:Packages:Convert2Dto1D:CCDImageToConvert
	if( str2num(StringByKey("CHESSG1MetadataLoaded",note(CCDImageToConvert),"=",";",1)) != 1)
		CHESSG1_LoadMetadata( StringByKey("DataFileName",note(CCDImageToConvert),"=",";",1))
	endif
	return str2num(StringByKey(valueToLoad,note(CCDImageToConvert),"=",";",0))
end

function CHESSG1_GetEmptyMetadata(valueToLoad)
	string valueToLoad
	wave/Z Empty = root:Packages:Convert2Dto1D:EmptyData
	if(exists("root:Packages:Convert2Dto1D:EmptyData") == 0)
		Abort ("Error - Select empty image file before attempting to reduce data with empty image!")
	endif
	if( str2num(StringByKey("CHESSG1MetadataLoaded",note(Empty),"=",";",1)) != 1)
		CHESSG1_LoadMetadata( StringByKey("DataFileName",note(Empty),"=",";",1))
	endif
	return str2num(StringByKey(valueToLoad,note(Empty),"=",";",0))
end

//spec file loader.  it's clunky, but it almost works most of the time.
Function/S CHESSG1_LoadMetadata(FileNameToLoad)
	String FileNameToLoad
	
	NVAR useDataFolder = root:Packages:Convert2Dto1D:CHESSG1usedatafolder
	String  emptyFileName = ""
	wave/Z Empty = root:Packages:Convert2Dto1D:EmptyData
	if(exists("root:Packages:Convert2Dto1D:EmptyData"))
		emptyFileName = StringByKey("DataFileName",note(Empty),"=",";",1)
	endif
	
	//important (useful) variables
		String scanHeaderList = ""
		String scanCommand = ""
		String scanMetadataList = ""
		String pointHeaderList = ""
		String pointMetadataList = ""
		String AllMetadataKeyValueList = ""
	
	//Split filename to find appropriate spec file name.  Assumes filename has format like:
	//    spec_filename_detID_scan#_point#.tiff

	//FileNameToLoad = ReplaceString(".tiff",ReplaceString(".tif",FileNameToLoad,""),"")
	
	String spec_filename, scan_str, point_str, ext, splitExpr
	Variable eiger_flag = 0
	
	if(strsearch(FileNameToLoad,"PIL",0)>-1) //This is a Pilatus image taken with the normal CHESS PILATUS macros.
		splitExpr = "(.*?)_PIL\d+_([[:digit:]]+)_([[:digit:]]+).(.*?)"
	elseif(strsearch(FileNameToLoad,".img", 0)>-1) //This is an ADSC image, we assume it was taken using the adx_from_spec macro.
		splitExpr = "(.*?)_([[:digit:]]+)_([[:digit:]]+).(.*?)"	
	elseif(strsearch(FileNameToLoad,"h5",0)>-1) //This is an hdf5 file, so probably from the Eiger
		Abort("Eiger HDF5 support is not implemented pending an improved version of Nika HDF5 code.")
	elseif(strsearch(FileNameToLoad,"master",0)>-1) //This is a tif file with "master" in the name, assume it was converted from Eiger
		//splitExpr = "(.*?)_([[:digit:]]+)_([[:digit:]]+)_master([[:digit:]]+).(.*?)"  this is the version for Eiger names with sequence number
		splitExpr = "(.*?)_([[:digit:]]+)_master([[:digit:]]+).(.*?)" // this is the version for Eiger names without sequence number
		
		eiger_flag=1
	elseif(strsearch(FileNameToLoad,"scan",0)>-1) //This is a tif file with "scan" in the name, assume it came from A2 macros
		splitExpr = "(.*?)_scan([[:digit:]]+)_([[:digit:]]+).(.*?)"
	elseif(strsearch(FileNameToLoad,"tiff",0)>-1) //This is a tiff file, so probably from a pilatus, see if we can turn it into something...
		print "Using generic tiff match rule"
		splitExpr = "(.*?)_([[:digit:]]+)_([[:digit:]]+).tiff"
	else
		Abort("Error: I don't recognize this image type.  Are you sure this is a supported dataset?")	
	endif
	Variable point_number
	if(eiger_flag)
		String seq_str
		SplitString /E=(splitExpr) FileNameToLoad, spec_filename, scan_str, point_str, ext
		if(strlen(scan_str) == 0) // if this fails, assume this is old code with sequence number
			splitExpr = "(.*?)_([[:digit:]]+)_([[:digit:]]+)_master([[:digit:]]+).(.*?)"
			SplitString /E=(splitExpr) FileNameToLoad, spec_filename, scan_str, seq_str, point_str, ext
		endif
		point_number = str2num(point_str) - 1 //EIGER images are off-by-one in numbering relative to PILATUS
	else
		SplitString /E=(splitExpr) FileNameToLoad, spec_filename, scan_str, point_str, ext
		point_number = str2num(point_str)
	endif
	
	
	Variable scan_number = str2num(scan_str)
	Print "looking in spec file " + spec_filename + " for point number " + num2str(point_number) + " in scan number " + num2str(scan_number)
	//Load spec file
	Variable fileRefNumber
	AllMetadataKeyValueList += "SpecFilename=" + spec_filename + ";"
	AllMetadataKeyValueList += "ScanNumber=" + num2str(scan_number) + ";"
	AllMetadataKeyValueList += "PointNumber=" + num2str(point_number) + ";"
	if(useDataFolder)
		if(stringmatch(FileNameToLoad,EmptyFileName))
			//load from the empty folder
			Open /P=Convert2Dto1DEmptyDarkPath /R /Z=1 fileRefNumber as spec_filename
		else
			//load from the data folder
			Open /P=Convert2Dto1DDataPath /R /Z=1 fileRefNumber as spec_filename
		endif
	else
		Open /P=SpecFilePath /R /Z=1 fileRefNumber as spec_filename
	endif
	
	if(V_flag != 0)
		Abort("Error: Problem with spec file path while loading G1 metadata.  Is the spec file where it should be and path set correctly?")
	endif
	
	//Load scan header variable names
	Variable linesRead = 0,linesReadLast = 0
	String specFileLine = ""
	String temp_list = ""
	String junk_str = ""
	do
		FReadLine fileRefNumber, specFileLine
		
		if(strlen(specFileLine) == 0) //the file has no more lines
			break
		endif
		linesReadLast = linesRead
		
		if (StringMatch(specFileLine[0,1], "#O")) //this is a header line, keep
			SplitString /E="#O\d+\s+(.*)\s+" specFileLine, temp_list
			scanHeaderList += temp_list + "   "
			temp_list = ""
			linesRead+= 1
		endif
		if(linesRead == linesReadLast && linesRead > 0)
			break
		endif
	while (1)

	scanHeaderList = ReplaceString("\r",scanHeaderList,"")
	
	//Load Scan metadata 
	
	do
		FReadLine fileRefNumber, specFileLine
		
		if(strlen(specFileLine) == 0) //the file has no more lines
			break
		endif
		if (StringMatch(specFileLine, "#S " + num2str(scan_number) + "*")) //this is a header line, keep
			SplitString /E="#S\s+\d+\s+(.*)" specFileLine,temp_list
			scanCommand = temp_list
			temp_list = ""
			break
		endif
	while (1)
	AllMetadataKeyValueList += "ScanCommand=" + ReplaceString("\r",scanCommand,"") + ";"
	
	linesReadLast = 0
	linesRead = 0
	do
		FReadLine fileRefNumber, specFileLine
		
		if(strlen(specFileLine) == 0) //the file has no more lines
			break
		endif
		linesReadLast = linesRead
		
		
		if (StringMatch(specFileLine[0,1], "#P")) //this is a header line, keep
			SplitString /E="#P\d+\s+(.*)\s+" specFileLine, temp_list
			scanMetadataList += temp_list+ " "
			temp_list = ""
			linesRead+= 1
		endif
		
		if(linesRead == linesReadLast && linesRead > 0)
			break
		endif
	while (1)
	
		scanMetadataList = ReplaceString("\r",scanMetadataList,"")

		
	//Go To Point and Load Point Metadata
	do
		FReadLine fileRefNumber, specFileLine
		
		if(strlen(specFileLine) == 0) //the file has no more lines
			break
		endif
		if (StringMatch(specFileLine, "#L*")) //this is a header line, keep
			SplitString /E="#L\s+(.*)\s+" specFileLine, temp_list
			pointHeaderList += temp_list+ "  "
			temp_list = ""
			break
		endif
	while (1)
	
	Variable counter
	
	for (counter = 0;counter<point_number;counter+=1)
		FReadLine fileRefNumber, specFileLine
	endfor
		FReadLine fileRefNumber, pointMetadataList
	
	scanHeaderList = NI1_ReduceSpaceRunsInString(scanHeaderList,2)
	scanHeaderList = ReplaceString("  ",scanHeaderList,";")	
	scanMetadataList = NI1_ReduceSpaceRunsInString(scanMetadataList,1)	

	counter = 0
	do
	
	if(strlen(StringFromList(counter,scanHeaderList, ";")) == 0)
		break
	endif
	AllMetadataKeyValueList += StringFromList(counter,scanHeaderList, ";") + "=" + StringFromList(counter,scanMetadataList," ") + ";"
	counter += 1
	while(1)

	pointHeaderList = NI1_ReduceSpaceRunsInString(pointHeaderList,2)
	pointHeaderList = ReplaceString("  ",pointHeaderList,";")
	pointMetadataList = NI1_ReduceSpaceRunsInString(pointMetadataList,1)
	
	counter = 0
	do
	
		if(strlen(StringFromList(counter,pointHeaderList, ";")) == 0)
			break
		endif
		
		if(strlen(StringByKey(StringFromList(counter,pointHeaderList,";"),AllMetadataKeyValueList,"=")) != 0) //there is a duplicate value of the motor scanned, remove the version from the scan header
			AllMetadataKeyValueList = RemoveByKey(StringFromList(counter,pointHeaderList,";"),AllMetadataKeyValueList,"=")
		endif
		AllMetadataKeyValueList += StringFromList(counter,pointHeaderList, ";") + "=" + StringFromList(counter,pointMetadataList," ") + ";"
		counter += 1
	while(1)
	AllMetadataKeyValueList = ReplaceString("\r",AllMetadataKeyValueList,"")
	AllMetadataKeyValueList = ReplaceString("\n",AllMetadataKeyValueList,"")  //these are to correct a strange issue where diode had a \r or \n after it...

	//Copy metadata to wavenote.

	wave/Z CCDImageToConvert = root:Packages:Convert2Dto1D:CCDImageToConvert
	wave/Z EmptyData = root:Packages:Convert2Dto1D:EmptyData
	
	
	string ImageToConvertName = StringByKey("DataFileName",note(CCDImageToConvert),"=",";",1)
	if(exists("root:Packages:Convert2Dto1D:EmptyData"))
		string EmptyImageName = StringByKey("DataFileName",note(EmptyData),"=",";",1)
	endif
	
	if(stringmatch(ImageToConvertName,FileNameToLoad))
		//we are loading metadata for the image to convert, put it there for later use.
		Note  CCDImageToConvert,";CHESSG1MetadataLoaded=1;"
		Note /NOCR CCDImageToConvert, AllMetaDataKeyValueList
	elseif(stringmatch(EmptyImageName,FileNameToLoad))
		//we are loading metadata for the empty image, put it there for later use.
		Note EmptyData,";CHESSG1MetadataLoaded=1;"
		Note /NOCR EmptyData, AllMetaDataKeyValueList
	else
		print("Warning - we seem to be loading metadata for an irrelevant file.")
	endif
	return AllMetadataKeyValueList
end


//GUI code


Function CHESSG1_ParameterPanel()

	String oldFolder = GetDataFolder(1)
	SetDataFolder root:Packages:Convert2Dto1D
	
	//create necessary variables
	String /G CHESSG1time
	String /G CHESSG1i0 
	String /G CHESSG1diode 
	Variable /G CHESSG1i0gain 
	Variable /G CHESSG1diodegain
	if(exists("CHESSG1usedatafolder"))
		 Variable /G CHESSG1usedatafolder
	else
		 Variable /G CHESSG1usedatafolder = 1
	endif
	
	//and set Nika defaults...
	Variable /G UseEmptyTimeFnct = 1
	Variable /G UseSampleMeasTimeFnct = 1
	Variable /G UseSampleMonitorFnct = 1
	Variable /G UseSampleTransmFnct = 1
	Variable/G UseEmptyTimeFnct = 1
	Variable /G UseEmptyMonitorFnct = 1
	
	String /G SampleTransmFnct = "CHESSG1_GetSampleTransmission"
	String /G SampleMonitorFnct = "CHESSG1_GetSampleI0"
	String /G EmptyMonitorFnct = "CHESSG1_GetEmptyI0"
	String /G SampleMeasTimeFnct = "CHESSG1_GetCountTime"
	String /G EmptyTimeFnct = "CHESSG1_GetEmptyCountTime" 

	//populate columns with default (reasonable) values if they are empty
	if(strlen(CHESSG1time) == 0)
		CHESSG1time = "Seconds"
	endif
	
	if(strlen(CHESSG1i0) == 0)
		CHESSG1i0 = "I2"
	endif
	
	if(strlen(CHESSG1diode) == 0)
		CHESSG1diode = "diode"
	endif
	

	PauseUpdate; Silent 1		// building window...
	NewPanel /W=(86,355,320,530)/N=CHESSG1_ParameterPanel /K=1
	SetDrawLayer UserBack
	DrawText 11,23,"CHESS G1 File Loader Parameters"
	DrawText 17,47,"1."
	DrawText 190,47, " -or-"
	CheckBox useDataFolder title="Ignore path, spec files saved with data \r (data taken after Spring 2015)",pos={35,50};DelayUpdate
	CheckBox useDataFolder variable=root:Packages:Convert2Dto1D:CHESSG1usedatafolder, proc=CHESSG1_EnableSpecFileButton
	Button selectSpecFileLocation,pos={35,29},size={150,20},title="Select spec file path"
	Button selectSpecFileLocation proc=CHESSG1_SelectSpecFilePath
	
	DrawText 20,95,"2. Assign counters & parameters:"
	PopupMenu CountTimeCounterSelect,pos={50,95},size={105,20},title="Count time: "
	PopupMenu CountTimeCounterSelect,mode=1,popvalue=CHESSG1time,value= #"\"Time;Epoch;Seconds;I1;I3;hepstat;hep;gdoor;r1_max;r2_sum;r1_sum;I2;diode;I0;Imono;IC1;IC2;IC3;IC4\""
	PopupMenu CountTimeCounterSelect proc=CHESSG1_SaveCounterValue
	PopupMenu I0CounterSelect,pos={50,120},size={66,20},title="I0: ",proc=CHESSG1_SaveCounterValue
	PopupMenu I0CounterSelect,mode=1,popvalue=CHESSG1i0,value= #"\"Time;Epoch;Seconds;I1;I3;hepstat;hep;gdoor;r1_max;r2_sum;r1_sum;I2;diode;I0;Imono\""
	PopupMenu DiodeCounterSelect,pos={50,145},size={82,20},title="Diode: ",proc=CHESSG1_SaveCounterValue
	PopupMenu DiodeCounterSelect,mode=1,popvalue=CHESSG1diode,value= #"\"Time;Epoch;Seconds;I1;I3;hepstat;hep;gdoor;r1_max;r2_sum;r1_sum;I2;diode;I0;Imono;IC1;IC2;IC3;IC4\""
	//@TODO  make the popup menus dynamically load the spec columns....
	PopupMenu i0GainSelect title="Gain",proc=CHESSG1_SaveCounterValue,mode=10;DelayUpdate
	PopupMenu i0GainSelect value="-9;-8;-7;-6;-5;-4;-3;-2;-1;0;1;2;3;4;5;6;7;8;9",pos={150,120}
	PopupMenu diodeGainSelect title="Gain",proc=CHESSG1_SaveCounterValue,mode=10;DelayUpdate
	PopupMenu diodeGainSelect value="-9;-8;-7;-6;-5;-4;-3;-2;-1;0;1;2;3;4;5;6;7;8;9",pos={150,145}
	SetDataFolder oldFolder
	 CHESSG1_EnableSpecFileButton("",0)
End

Function CHESSG1_SelectSpecFilePath(ctrlName) : ButtonControl
	String ctrlName
	
	PathInfo/S SpecFilePath
	String oldFolder = GetDataFolder(1)
	SetDataFolder root:Packages:Convert2Dto1D
	NewPath/C/O/M="Select path to your spec data files" SpecFilePath
	SetDataFolder oldFolder
End

Function CHESSG1_EnableSpecFileButton(ctrlName,checked) : CheckboxControl
	String ctrlName
	Variable checked
	NVAR UseDataFolder=root:Packages:Convert2Dto1D:CHESSG1usedatafolder
	if(UseDataFolder)
		ModifyControl selectSpecFileLocation disable=2
	else
		ModifyControl selectSpecFileLocation disable=0
	endif
End

Function CHESSG1_SaveCounterValue(pa) : PopupMenuControl
	STRUCT WMPopupAction &pa
	SVAR timeSpecCounter = root:Packages:Convert2Dto1D:CHESSG1time
	SVAR i0SpecCounter = root:Packages:Convert2Dto1D:CHESSG1i0
	SVAR diodeSpecCounter = root:Packages:Convert2Dto1D:CHESSG1diode
	NVAR i0Gain = root:Packages:Convert2Dto1D:CHESSG1i0gain
	NVAR diodeGain = root:Packages:Convert2Dto1D:CHESSG1diodegain

	switch( pa.eventCode )
		case 2: // mouse up
			String popStr = pa.popStr
			strswitch (pa.ctrlName)
			case "CountTimeCounterSelect":
				timeSpecCounter = popStr
				break
			case "I0CounterSelect":
				i0SpecCounter = popStr
				break
			case "DiodeCounterSelect":
				diodeSpecCounter = popStr
				break
			case "i0GainSelect":
				i0Gain = str2num(popStr)
				break
			case "diodeGainSelect":
				diodeGain = str2num(popStr)
				break
			endswitch	
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End


Function SpecParameterList(FileToLoad)
	String FileToLoad

End

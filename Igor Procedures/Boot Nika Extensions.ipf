#pragma rtGlobals=1		// Use modern global access method and strict wave access.

Menu "Macros"
		StrVarOrDefault("root:Packages:CHESSG1Item1Str","Load CHESS Extension"), LoadCHESSG1()
		StrVarOrDefault("root:Packages:IMGEXPItem1Str","Load Image Export"), LoadIMGEXP()
		StrVarOrDefault("root:Packages:DYNSDDItem1Str","Load Dynamic SDD"), LoadDYNSDD()
		StrVarOrDefault("root:Packages:DYNSDDItem1Str","Load Nika + ALL PB extensions"), LoadNikaPlusPB()
end

Proc LoadCHESSG1()
	Execute /P "INSERTINCLUDE \"CHESSG1\""
	Execute /P "COMPILEPROCEDURES "
	NewDataFolder /O root:Packages
	string /g root:Packages:CHESSG1Item1Str
	root:Packages:CHESSG1Item1Str="---"
end
Proc LoadIMGEXP()
	Execute /P "INSERTINCLUDE \"AddImageExportToNika\""
	Execute /P "COMPILEPROCEDURES "
	NewDataFolder /O root:Packages
	string /g root:Packages:IMGEXPItem1Str
	root:Packages:IMGEXPItem1Str="---"
end
Proc LoadDYNSDD()
	Execute /P "INSERTINCLUDE \"Nika_DynamicSDD\""
	Execute /P "COMPILEPROCEDURES "
	NewDataFolder /O root:Packages
	string /g root:Packages:DYNSDDItem1Str
	root:Packages:DYNSDDItem1Str="---"
end

Proc LoadNikaPlusPB()
	LoadNika2DSASMacros()
	LoadCHESSG1()
	LoadIMGEXP()
	LoadDYNSDD()
end


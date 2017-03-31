#pragma rtGlobals=1		// Use modern global access method.
#pragma version=1


Menu "Macros"
	StrVarOrDefault("root:Packages:PTItem1Str","Load Peak Tools"), LoadPeakTools()
	StrVarOrDefault("root:Packages:IMGItem1Str","Load Nika Image Export Extension"), LoadNikaImageExport()	
end


Proc LoadPeakTools()
		Execute/P "INSERTINCLUDE \"PF_MainProcedure\""
		Execute/P "COMPILEPROCEDURES "
		NewDataFolder/O root:Packages
		string /g root:Packages:PTItem1Str
		root:Packages:PTItem1Str="---"
end

Proc LoadNikaImageExport()
		Execute /P "INSERTINCLUDE \"AddImageExportToNika\""
		Execute /P "COMPILEPROCEDURES "
		NewDataFolder /O root:Packages
		string /g root:Packages:IMGItem1Str
		root:Packages:IMGItem1Str="---"
end



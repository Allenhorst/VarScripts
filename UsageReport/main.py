import  os
import  sys
import DiskUsage as DU
import datetime
import importlib.util
spec = importlib.util.spec_from_file_location("Teamcity", "..\TA_TestReport\Teamcity.py")
TC = importlib.util.module_from_spec(spec)
spec.loader.exec_module(TC)

DU.DiskUsage.__init__(DU.DiskUsage, username="adacc",
                     password="jd7gowuX",
                     server="http://vmsk-tc-prm.paragon-software.com",
                     port=None
                     )
#builds = TC.Teamcity.getLastBuildsByDate(TC.Teamcity,"Prm_Tests_Sdkl1_723sdkFastWixFullLi", "20170727T000000%2B0300")
#project = TC.Teamcity.getSubprojectsFromProject(TC.Teamcity, "PrmF100716")

#print(project)

#DU.DiskUsage.buildTree(DU.DiskUsage, "PrmBackup")
print ("Work begins :" + str(datetime.datetime.now()))
t = DU.DiskUsage.getAllBuildsArtsize(DU.DiskUsage, "Prm_Sandbox_2Tsypunov")

print (t)

DU.DiskUsage.buildCustomTree(DU.DiskUsage, "Prm_Sandbox_2Tsypunov")
DU.DiskUsage.projectToJSON(DU.DiskUsage, "Prm_Sandbox_2Tsypunov")

#for k, v in DU.DiskUsage.projectsArtSize.items():
#    print(k +" : "+ "%.3f" %(v/1048576) + " Mb")

print("Work ends :" + str(datetime.datetime.now()))

import Teamcity as TC
import os
allBuildIds = []
allBuildNames = []
allTestsProjectIds = ["Prm_Tests_L1", "Prm_Tests_L2", "Prm_Tests_L3"]
excludeProjectIds = ["Investigate", "Legacy"] #to do add real id
agentId = "ta-srv1162-f3"
filename = "report_" + agentId + ".html"
startHTML = "\r\n<html> <body> \r\n<table border=1 cellpadding=10 cellspacing=0> <tr><tr> \r\n"
endHTML = "\r\n\r\n</html> </body>\r\n</tr> </table>\r\n"

TC.Teamcity.__init__(TC.Teamcity,username="paragon\\tsypunov",
                                 password="vbhjrkjp_5",
                                 server="http://vmsk-tc-prm.paragon-software.com",
                                 port=None
                                 )

#TC.Teamcity.getBuildById(TC.Teamcity, buildId="bt261")
#TC.Teamcity.getLastSuccessfulBuildById(TC.Teamcity, buildId="bt261")
#agentId = TC.Teamcity.getAgentIdByName(TC.Teamcity, "ta-srv1112-80")
#TC.Teamcity.getProjectById(TC.Teamcity, "Prm_Tests_L1")

#TC.Teamcity.getLastSuccessfulBuildByIdAndagent(TC.Teamcity, "Prm_Tests_970serviceTestsExecutor","ta-srv1162-f3")

#for Pr_ids in allTestsProjectIds:
#    buildids = TC.Teamcity.getAllBuildTypesForProject(TC.Teamcity, Pr_ids)
#    buildnames = TC.Teamcity.getAllBuildTypesForProjectNames(TC.Teamcity, Pr_ids)
#    allBuildIds+=buildids
#    allBuildNames+=buildnames
##print(allBuildIds)
#
##    print (v+ "=> " + k)

#build = TC.Teamcity.getBuildById(TC.Teamcity, Id="2258989")
#buildUrl, buildName, buildVer = TC.Teamcity.getInformationFromBuild(TC.Teamcity, build)
#print("end")
try:
    os.remove(filename)
except FileNotFoundError as e:
    pass

try:
    f = open(filename, "w+")
except OSError as e:
    pass



for Pr_ids in allTestsProjectIds:
   buildids = TC.Teamcity.getAllBuildTypesForProject(TC.Teamcity, Pr_ids)
   buildnames = TC.Teamcity.getAllBuildTypesForProjectNames(TC.Teamcity, Pr_ids)
   allBuildIds += buildids
   allBuildNames += buildnames

print(agentId)
allBuildIds.append("Prm_Tests_300smokeMainWithSdk")
allBuildNames.append("300 SMOKE Main with SDK")
allBuildIds.append("Prm_Tests_310unitUniversal")
allBuildNames.append("310 UNIT Universal")

#f = open(filename)
f.write(startHTML)

for buildID in allBuildIds:
    lastBuild = TC.Teamcity.getLastSuccessfulBuildByIdAndagent(TC.Teamcity, buildID, agentId)
    #print (lastBuild)

    if lastBuild:
        buildText = TC.Teamcity.getBuildById(TC.Teamcity, str(lastBuild))
        buildUrl, buildName, buildVer = TC.Teamcity.getInformationFromBuild(TC.Teamcity, buildText)
        out = "<tr> <td valign=top>" + buildName + "</td> <td valign=top>  " + buildVer + "</td> <td valign=top> " + "<a href=\"" + buildUrl + "\" style=color: #9ACD32>" + "SUCCESS" + "</a>" + " \n"
    else:
        buildName = TC.Teamcity.getBuildNameByBuildId(TC.Teamcity,buildID)
        buildVer = "N\A "
        compatibleAgents = TC.Teamcity.getCompatibleAgentsForBuild(TC.Teamcity, buildID)
        if agentId not in compatibleAgents:
            buildUrl = "agent not compatible"
        else:
            buildUrl = "No builds of this kind"
        out = "<tr> <td valign=top>" + buildName + "</td> <td valign=top>  " + buildVer + "</td> <td valign=top> " +  buildUrl +  " \n"
    output = "Build Name: " + buildName + " Version: " + buildVer + "URL: " +buildUrl

    #print(output)
    f.write(out)

f.write(endHTML)
f.close()


#buildID = "Prm_Tests_Sdkl3_Core_7093sdkStressTaskManagerDatabase"
#lastBuild = TC.Teamcity.getLastSuccessfulBuildByIdAndagent(TC.Teamcity, buildID, agentId)

import Teamcity as TC
import os
import sys

allBuildIds = []
allBuildNames = []
allTestsProjectIds = ["Prm_Tests_L1", "Prm_Tests_L2", "Prm_Tests_L3", "Prm_Tests_Newfn"]
excludeProjectIds = ["Investigate", "Legacy"]  # to do add real id
defaultAgentId = "ta-srv1148-am"
try:
    agentId = sys.argv[1]
except IndexError as e:
    agentId = defaultAgentId

#filename = "report_" + agentId + ".html"
filename1 = "alltest1.txt"

startHTML = "\r\n<html> <body> \r\n<table border=1 cellpadding=10 cellspacing=0> <tr><tr> \r\n"
endHTML = "\r\n</tr> </table>\r\n\r\n </body> </html>\r\n"

TC.Teamcity.__init__(TC.Teamcity, username="adacc",
                     password="jd7gowuX",
                     server="http://vmsk-tc-prm.paragon-software.com",
                     port=None
                     )

#try:
#    os.remove(filename)
#except FileNotFoundError as e:
#    pass

#try:
#    f = open(filename, "w+")
#except OSError as e:
#    pass

allBuildIds.append("Prm_Tests_300smokeMainWithSdk")
allBuildNames.append("VB300 SMOKE Main ")


for Pr_ids in allTestsProjectIds:
    buildids = TC.Teamcity.getAllBuildTypesForProject(TC.Teamcity, Pr_ids)
    buildnames = TC.Teamcity.getAllBuildTypesForProjectNames(TC.Teamcity, Pr_ids)
    allBuildIds += buildids
    allBuildNames += buildnames


## uncomment to get all test configurations
f = open(filename1, "w+")

for k,v in zip (allBuildIds, allBuildNames) :
    f.write( "\"" + v + "=>" + k + "\"\n" )

f.close()

print(agentId)

f.write(startHTML)
out = "<h1>" + agentId + "</h1>\n"
f.write(out)
for buildID in allBuildIds:
    lastBuild = TC.Teamcity.getLastSuccessfulBuildByIdAndagent(TC.Teamcity, buildID, agentId)

    if lastBuild:
        buildText = TC.Teamcity.getBuildById(TC.Teamcity, str(lastBuild))
        buildUrl, buildName, buildVer = TC.Teamcity.getInformationFromBuild(TC.Teamcity, buildText)
        out = "<tr> <td valign=top>" + buildName + "</td> <td valign=top>  " + buildVer + "</td> <td valign=top> " + "<a href=\"" + buildUrl + "\" style=color: #9ACD32>" + "SUCCESS" + "</a>" + " \n"
    else:
        buildName = TC.Teamcity.getBuildNameByBuildId(TC.Teamcity, buildID)
        buildVer = "N\A "
        compatibleAgents = TC.Teamcity.getCompatibleAgentsForBuild(TC.Teamcity, buildID)
        if agentId not in compatibleAgents:
            buildUrl = "agent not compatible"
        else:
            buildUrl = "No builds of this kind"
        out = "<tr> <td valign=top>" + buildName + "</td> <td valign=top>  " + buildVer + "</td> <td valign=top> " + buildUrl + " \n"
    output = "Build Name: " + buildName + " Version: " + buildVer + "URL: " + buildUrl

    f.write(out)

f.write(endHTML)
f.close()



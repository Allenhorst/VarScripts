import DiskUsage
import loader
import Reporter
import sys
import os
import fnmatch
import treelib
import datetime
import teamcity.messages as tm

"""
consider input filename as rootId-yy-mm-dd-hh-mm-ss.json
TO DO: need to rename it during build, or when reporter is running, this allows to find the most relevant report

"""
def findFile(pattern, path):
    result = []
    for root, dirs, files in os.walk(path):
        for name in files:
            if fnmatch.fnmatch(name, pattern):
                result.append(os.path.join(root, name))
    return result

def findLastFile(files):
    t = sorted(files).pop()
    return t


TM = tm.TeamcityServiceMessages()


curPath = os.getcwd()

TM.blockOpened("Constructing started")

"""
Check input parameters :
1. Id of root project to inspect
2. Depth of subproject to inspect
3. Max count of subprojects reports
"""
#rootID = "_Root"
rootID = "Prm_Sandbox"
try:
    rootProjectId = sys.argv[1]
except IndexError as e:
    rootProjectId = rootID

TM.message("Root project id is " , rootProjectId)

try:
    max_dLevel = int(sys.argv[2])
except IndexError as e:
    max_dLevel = 2

TM.message("Max depth of subprojects is " , str(max_dLevel))
try:
    max_wLevel = sys.argv[3]
except IndexError as e:
    max_wLevel = 3

TM.message("Max number of reported subprojects/builds  of a project is " , str(max_wLevel))

fileToFind = rootProjectId+"-*"
reports = findFile(fileToFind, curPath+"\\Reports")

DiskUsage.DiskUsage.__init__(DiskUsage.DiskUsage, username="adacc",
                             password="jd7gowuX",
                             server="http://vmsk-tc-prm.paragon-software.com",
                             port=None,
                             jsonname=rootProjectId
                             )
TM.blockOpened("Begin collecting current artifact size")
DiskUsage.DiskUsage.getAllBuildsArtsize(DiskUsage.DiskUsage, rootProjectId)
TM.blockClosed("Ended collecting current artifact size")
TM.blockOpened("Begin building artifact size tree")
tree = DiskUsage.DiskUsage.buildCustomTree(DiskUsage.DiskUsage, rootProjectId)
TM.blockClosed("Ended building artifact size tree")
TM.blockOpened("Begin writing artifact size tree to JSON")
DiskUsage.DiskUsage.projectToJSON(DiskUsage.DiskUsage, rootProjectId)
TM.blockClosed("Ended writing artifact size tree to JSON")
DiskUsage.DiskUsage.closeFile(DiskUsage.DiskUsage)
L = loader.Loader(DiskUsage.DiskUsage.path)
js1 = L.parseJson(DiskUsage.DiskUsage.path)
new = loader.Loader.addProjectNode(loader.Loader, jsondata=js1)

if reports == [] :
    # no suitable reports - generate one and make html report based on it
    TM.message("No suitable reports - generate one and make html report based on it", "")
    TM.blockOpened("Begin generating report")
    text = Reporter.Reporter.generateReport(Reporter.Reporter, new, max_dLevel, max_wLevel)
    TM.blockClosed("Ended generating report")
    header1 = "<tr><th colspan=\"2\"><h1>Report represents current artifacts size in project with id " + rootProjectId +"</h1></th></tr>"
    header2 = "<tr><td><h2>Configuration Name(Conf ID)<h2></td><td><h2> Current artifact size</h2></td></tr>"
else:
    TM.message("Find appropriate report - build comparative html report", "")
    TM.blockOpened("Begin generating report")
    lastReport = findLastFile(reports)
    L1 = loader.Loader(lastReport)
    js = L1.parseJson(lastReport)
    loader.Loader.tree= treelib.Tree()
    old = loader.Loader.addProjectNode(loader.Loader, jsondata=js)
    text = Reporter.Reporter.generateCompReport(Reporter.Reporter, new, old, max_dLevel, max_wLevel)
    TM.blockClosed("Ended generating report")
    old_time = lastReport[-24:-5]
    header1 = "<tr><th colspan=\"3\"><h1>Report represents changes in artifacts size in project with id  " + rootProjectId + "  from time"+ old_time+ "</h1></th></tr>"
    header2 = "<tr>" \
              "<td><h2>Configuration Name(Conf ID)</h2></td>"\
              "<td><h2>Change</h2></td>"\
              "<td><h2>Artifact size</h2></td>" \
              "</tr>"



toRemove =findFile("report*", curPath+"\\HTMLs")
for f in toRemove:
    os.remove(f)


htmlname = "reportss.html"
startHTML = "\r\n<html> <body> \r\n<table border=1 cellpadding=10 cellspacing=0>  \r\n"
#header2 = "<tr><td>Configuration Name(Conf ID)</td><td> Artifact size</td></tr>"
endHTML = "</table> </body>\r\n</html> "

try:
    os.remove(htmlname)
except FileNotFoundError as e:
    pass

try:
    f = open(curPath+"\\HTMLs\\"+htmlname, "w+")
except OSError as e:
    pass
TM.blockOpened("Started writing report to file")
f.write(startHTML)
f.write(header1)
f.write(header2)
f.write(text)
f.write(endHTML)

DiskUsage.DiskUsage.closeFile(DiskUsage.DiskUsage)
TM.blockOpened("Ended writing report to file")
toRemove =findFile("tree*", curPath+"\\Reports")
for f in toRemove:
    os.remove(f)


TM.blockOpened("Constructing ended")

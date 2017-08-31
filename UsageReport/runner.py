import DiskUsage
import loader
import Reporter
import sys
import os
import fnmatch
import treelib

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





curPath = os.getcwd()
#rootID = "_Root"
rootID = "Prm_Sandbox_2Sintsov"
try:
    rootProjectId = sys.argv[1]
except IndexError as e:
    rootProjectId = rootID

fileToFind = rootProjectId+"*"
reports = findFile(fileToFind, curPath+"\\Reports")

DiskUsage.DiskUsage.__init__(DiskUsage.DiskUsage, username="adacc",
                             password="jd7gowuX",
                             server="http://vmsk-tc-prm.paragon-software.com",
                             port=None,
                             jsonname=rootProjectId
                             )

DiskUsage.DiskUsage.getAllBuildsArtsize(DiskUsage.DiskUsage, rootProjectId)
tree = DiskUsage.DiskUsage.buildCustomTree(DiskUsage.DiskUsage, rootProjectId)
DiskUsage.DiskUsage.projectToJSON(DiskUsage.DiskUsage, rootProjectId)
DiskUsage.DiskUsage.closeFile(DiskUsage.DiskUsage)
L = loader.Loader(DiskUsage.DiskUsage.path)
js1 = L.parseJson(DiskUsage.DiskUsage.path)
new = loader.Loader.addProjectNode(loader.Loader, jsondata=js1)

if reports == [] :
    # no suitable reports - generate one and make html report based on it
    text = Reporter.Reporter.generateReport(Reporter.Reporter, new, 2)
else:
    lastReport = findLastFile(reports)
    L1 = loader.Loader(lastReport)
    js = L1.parseJson(lastReport)
    loader.Loader.tree= treelib.Tree()
    old = loader.Loader.addProjectNode(loader.Loader, jsondata=js)
    text = Reporter.Reporter.generateCompReport(Reporter.Reporter, new, old, 2)



htmlname = "reportss.html"
startHTML = "\r\n<html> <body> \r\n<table border=1 cellpadding=10 cellspacing=0>  \r\n"
endHTML = "</table> </body>\r\n</html> "

try:
    os.remove(htmlname)
except FileNotFoundError as e:
    pass

try:
    f = open(htmlname, "w+")
except OSError as e:
    pass
f.write(startHTML)
f.write(text)
f.write(endHTML)

DiskUsage.DiskUsage.closeFile(DiskUsage.DiskUsage)
toRemove =findFile("tree*", curPath+"\\Reports")
for f in toRemove:
    os.remove(f)

import DiskUsage
import loader
import Reporter
import sys
import os
import fnmatch

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

    t= sorted(files).pop()
    return t


def generateReport(jsondata,level):



curPath = os.getcwd()
#find('*.txt', '/path/to/dir')






DiskUsage.DiskUsage.__init__(DiskUsage.DiskUsage, username="adacc",
                         password="jd7gowuX",
                         server="http://vmsk-tc-prm.paragon-software.com",
                         port=None
                         )

rootID = "_Root"
try:
    rootProjectId = sys.argv[1]
except IndexError as e:
    rootProjectId = rootID

fileToFind = rootProjectId
results = findFile(fileToFind, curPath+"//Reports")
lastReport = ""






if results == []:
    #no files found, generating clear report
    generateReport()
else:
    generateCompReport()




L = loader.Loader("tree2.json")
js = L.parseJson("tree2.json")
#t = L.addProjectNode(js)
old = loader.Loader.addProjectNode(loader.Loader, jsondata=js )

t = DiskUsage.DiskUsage.getAllBuildsArtsize(DiskUsage.DiskUsage, "Prm_Sandbox_2Sintsov")
new = DiskUsage.DiskUsage.buildCustomTree(DiskUsage.DiskUsage, "Prm_Sandbox_2Sintsov")


#L1 = loader.Loader("tree3.json")
#js1 = L1.parseJson("tree3.json")
#new = loader.Loader.addProjectNode(loader.Loader, jsondata=js1 )

diff = Reporter.Reporter.buildReport(Reporter.Reporter,new, old )
for k,v in diff.items():
    print (k + "  :  " + str(v))

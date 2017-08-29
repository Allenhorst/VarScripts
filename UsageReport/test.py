import DiskUsage
import loader
import Reporter

DiskUsage.DiskUsage.__init__(DiskUsage.DiskUsage, username="adacc",
                         password="jd7gowuX",
                         server="http://vmsk-tc-prm.paragon-software.com",
                         port=None
                         )

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

import json
import importlib.util
import os
import treelib
from DiskUsage import customProjectNode, BuildNode, DiskUsage

class Loader():
    filename = ""
    tree = treelib.Tree()
    text = ""
    jsoned = ""
    def __init__(self,filename):
        self.filename = filename

    def parseJson(self, filename):
        with open(filename) as f:
            jsoned = json.load(f)

            return jsoned

    def buildCustomTree(self, jsondata):
        return  0

    def addProjectNode(self,jsondata, parent=None):
        artSize  = jsondata["ArtSize"]
        prID  = jsondata["Project Id"]
        prName   = jsondata["Project Name"]
        subPr = jsondata["SubProjects"]
        dirBuilds = jsondata["directBuilds"]

        subProjectsCount = DiskUsage.getSubProjectsCount(DiskUsage,subPs=subPr)
        if self.tree.contains(prID):
            return
        else:
            self.tree.create_node(prName,prID,parent=parent, data=customProjectNode(prID,parent,artSize))

            if (dirBuilds != "None"):
                for dB in dirBuilds:
                    dbId = dB["Build Id"]
                    dbName = dB["Build Name"]
                    dbAS = dB["ArtSize"]
                    self.tree.create_node(dbName, dbId, parent=prID,data=customProjectNode(dB, prID, dbAS ))
            if subProjectsCount > 0:
                roots = subPr
                subProjects = []

                if roots != "None" :
                    for root in roots:

                        subPrs = jsondata["SubProjects"]
                        if subPrs:
                            subProjects += subPrs
                            subPrsCount = len(subPrs)
                        else:
                            subPrsCount = 0
                        subProjectsCount += subPrsCount
                        self.tree.save2file("tree3.txt")
                        print
                        self.addProjectNode(self, jsondata=root, parent=prID)
                    subProjectsCount -=1

        #print("done")
        return self.tree



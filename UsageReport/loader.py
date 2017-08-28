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
        self.tree.create_node(prName,prID,parent=parent, data=customProjectNode(prID,parent,artSize))

        if dirBuilds:
            for dB in dirBuilds:
                dbId = dB["Build Id"]
                dbName = dB["Build Name"]
                dbAS = dB["ArtSize"]
                self.tree.create_node(dbName, dbId, parent=prID,data=customProjectNode(dB, prID, dbAS ))
        while subProjectsCount > 0:
            roots = subPr
            subProjects = []
            subProjectsCount = 0
            for root in roots:

                subPrs = jsondata["SubProjects"]
                if subPrs:
                    subProjects += subPrs
                    subPrsCount = len(subPrs)
                else:
                    subPrsCount = 0
                subProjectsCount += subPrsCount
                self.addProjectNode(root,parent=prID)

        #print("done")
        return self.tree



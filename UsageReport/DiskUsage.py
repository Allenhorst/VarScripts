import json
import importlib.util
import os
import treelib
import jsonpickle
import joblib
import datetime

#spec = importlib.util.spec_from_file_location("Teamcity", "..\TA_TestReport\Teamcity.py")
#TC = importlib.util.module_from_spec(spec)
#spec.loader.exec_module(TC)


filename = "tree2.txt"
jsonname ="tree.json"

try:
    import Teamcity as TC
except ModuleNotFoundError as e:
    spec = importlib.util.spec_from_file_location("TC", "D:\\Scripts\\TA_TestReport\\Teamcity.py")
    TC = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(TC)

class BuildNode():
    name = None
    parent = None
    artSize = 0

    def __init__(self, name,parent, size):
        self.name = name
        self.parent = parent
        self.artSize = size
    def toJSON(self):
        #return json.dumps(self, default=lambda o: o.__dict__, indent=4)
        return jsonpickle.dumps(self)

class ProjectNode():
    name = None
    parent = None
    subProjects = None
    subProjectsCount = 0
    directBuilds = None
    artSize = 0

    def __init__(self, name, parent, subP , subPCount, dBuilds, artSize):
        self.name = name
        self.parent = parent
        self.subProjects = subP
        self.subProjectsCount = subPCount
        self.directBuilds = dBuilds
        self.artSize = artSize

    def toJSON(self):
        return json.dumps(self, default=lambda o: o.__dict__,indent=2)

class customProjectNode():
    name = None
    parent = None
    artSize = 0
    data= ""

    def __init__(self, name, parent,  artSize):
        self.name = name
        self.parent = parent
        self.artSize = artSize
        self.data = str(name) + " : " + str(artSize)

    def toJSON(self):
        #return json.dumps(self, default=lambda o: o.__dict__,indent=4)
        return jsonpickle.dumps(self)

class DiskUsage(TC.Teamcity):
    buildsArtSize = {}
    projectsArtSize = {}
    tree = treelib.Tree()
    jsonname = "tree"
    jsonfile = None
    path=""
    def __init__(self, username=None, password=None, server=None, port=None,session=None, protocol=None, jsonname=jsonname):
        super(DiskUsage, self).__init__(TC.Teamcity, username=username, password=password, server=server, port=port,
                 session=session, protocol=protocol)

        jsonname = jsonname+"-"+(datetime.datetime.now().isoformat(sep='-')[:-7]).replace(':','-')+".json"
        try:
            self.path = os.getcwd()+"\\Reports\\"+jsonname
            self.jsonfile = open(self.path, "w+")
        except OSError as e:
            pass

    def closeFile(self):
        self.jsonfile.close()

    def dateComparer(self, firstDate, secondDate):
        delta_0 = secondDate - firstDate
        delta = delta_0.days*86400 + delta_0.seconds
        if delta > 0 :
            return 1
        elif delta == 0 :
            return 0
        else :
            return -1


    def getSubProjectsCount(self, subPs):
        try:
            count = len(subPs)
        except TypeError as e:
            count = 0
        return count

    def getNodesDirectLeaves(self, tree, node):
        leaves = tree.leaves(node)
        dirleaves = []
        for leaf in leaves:
            if leaf.bpointer == node :
                dirleaves.append(leaf)
        return dirleaves

    def getAllBuildsArtsize(self, rootProjectID):

        directBuilds = TC.Teamcity.getBuildsDirectlyFromProject(TC.Teamcity, rootProjectID)
        subProjects = TC.Teamcity.getSubprojectsFromProject(TC.Teamcity, rootProjectID)
        if rootProjectID not in self.projectsArtSize.keys():

            try:
                subProjectsCount = len(subProjects)
            except TypeError as e:
                subProjectsCount = 0
            buildsSize = 0
            builds = []
            if directBuilds == 0:
                pass
            else:
                for dBuild in directBuilds:

                    if dBuild not in self.buildsArtSize.keys():
                        buildsSizeL = 0
                        builds = TC.Teamcity.getListOfBuildsByCountAndDate(TC.Teamcity,dBuild, count=16, date=8)
                        acc = 0
                        build_s = ""
                        with joblib.Parallel(n_jobs=8, backend="threading") as parallel:

                            build_s = parallel(joblib.delayed(TC.Teamcity.getArtifactsSizeById)(TC.Teamcity,build) for build in builds)

                            for i in build_s: acc += int(i)
                            buildsSizeL += acc
                        self.buildsArtSize[dBuild] = buildsSizeL
                        buildsSize += buildsSizeL
                    else:
                        buildsSize = self.buildsArtSize[dBuild]
            if subProjectsCount == 0 :
                pass
            else:
                #for subP in subProjects:
                #    t = self.getAllBuildsArtsize(self,subP)#
                #    buildsSize += int(t)
                acc = 0
                with joblib.Parallel(n_jobs=8, backend="threading") as parallel:

                    build_s = parallel(
                        joblib.delayed(self.getAllBuildsArtsize)(self, subP) for subP in subProjects)

                    for i in build_s: acc += int(i)
                    buildsSize += acc
            self.projectsArtSize[rootProjectID] = buildsSize
        else:
            buildsSize = self.projectsArtSize[rootProjectID]
        return buildsSize

    def buildTree(self, rootProjectID):
        directBuilds = TC.Teamcity.getBuildsDirectlyFromProject(TC.Teamcity, rootProjectID)
        subProjects = TC.Teamcity.getSubprojectsFromProject(TC.Teamcity, rootProjectID)
        subProjectsCount = DiskUsage.getSubProjectsCount(self, subProjects)
        tree = treelib.Tree()
        roottree = ProjectNode(rootProjectID, None, subProjects, subProjectsCount, directBuilds, self.projectsArtSize[rootProjectID])
        tree.create_node(rootProjectID, rootProjectID, data=roottree.toJSON())

        while subProjectsCount > 0:
            roots = subProjects
            subProjects = []
            subProjectsCount = 0
            for root in roots:
                dirBuilds = TC.Teamcity.getBuildsDirectlyFromProject(TC.Teamcity,root)
                subPrs = TC.Teamcity.getSubprojectsFromProject(TC.Teamcity, root)
                if subPrs:
                    subProjects += subPrs
                    subPrsCount = len(subPrs)
                else:
                    subPrsCount = 0
                subProjectsCount += subPrsCount
                parent = TC.Teamcity.getParentProject(TC.Teamcity, root)
                node = ProjectNode(root, parent, subPrs, subPrsCount, dirBuilds, self)
                tree.create_node(root,root, parent=parent,data=node.toJSON())

        # return tree #by this moment we can return out tree and work directly with it



        #tree.show(line_type="ascii-em")
        try:
            os.remove(filename)
        except FileNotFoundError as e:
            pass
        tree.save2file(filename=filename)

        jsoned = (tree.to_json(with_data=True)).replace("\\n","\n").replace("\\","")
        try:
            os.remove(jsonname)
        except FileNotFoundError as e:
            pass

        try:
            f = open(jsonname, "w+")
        except OSError as e:
            pass

        f.write(jsoned)
        f.close()

        print(json.loads(tree.to_json(with_data=True)))

    def getFormattedSize(self, size):
        return str("%.3f" % (int(size)/1048576)) + " : " + "Mb"

    def buildCustomTree(self, rootProjectID):

        directBuilds = TC.Teamcity.getBuildsDirectlyFromProject(TC.Teamcity, rootProjectID)
        subProjects = TC.Teamcity.getSubprojectsFromProject(TC.Teamcity, rootProjectID)
        subProjectsCount = DiskUsage.getSubProjectsCount(self, subProjects)
        self.tree = treelib.Tree()
        #roottree = customProjectNode(rootProjectID, None, self.projectsArtSize[rootProjectID])

        self.tree.create_node(rootProjectID, rootProjectID, data=customProjectNode(rootProjectID, None,self.getFormattedSize(self,self.projectsArtSize[rootProjectID])))
        if directBuilds:
            for dB in directBuilds:
                #node = customProjectNode(dB, rootProjectID, self.buildsArtSize[dB])
                self.tree.create_node(dB, dB, parent=rootProjectID,

                                data=customProjectNode(dB, rootProjectID, self.getFormattedSize(self,self.buildsArtSize[dB])  ))
        while subProjectsCount > 0:
            roots = subProjects
            subProjects = []
            subProjectsCount = 0
            for root in roots:
                dirBuilds = TC.Teamcity.getBuildsDirectlyFromProject(TC.Teamcity, root)
                subPrs = TC.Teamcity.getSubprojectsFromProject(TC.Teamcity, root)
                if subPrs:
                    subProjects += subPrs
                    subPrsCount = len(subPrs)
                else:
                    subPrsCount = 0
                subProjectsCount += subPrsCount
                parent = TC.Teamcity.getParentProject(TC.Teamcity, root)
                node = customProjectNode(root, parent,  self.projectsArtSize[root])

                self.tree.create_node(root, root, parent=parent, data=customProjectNode(root, parent, self.getFormattedSize(self,self.projectsArtSize[root])))
                if dirBuilds :
                    for dB in dirBuilds:
                        node = customProjectNode(dB, root, self.buildsArtSize[dB])

                        self.tree.create_node(dB, dB, parent=root, data=customProjectNode(dB, root, self.getFormattedSize(self,self.buildsArtSize[dB])))
                        # return tree #by this moment we can return out tree and work directly with it
        self.tree.save2file(filename=filename,data_property="data")
        return self.tree
        #jsoned = tree.to_json()

    def buildToJSON(self,buildID):
        bID = buildID.data.name
        bName = TC.Teamcity.getBuildNameByBuildId(TC.Teamcity, bID)
        size = (self.tree.get_node(bID)).data.artSize
        try:
            self.jsonfile.write("{ \"Build Name\" : \"" + bName.replace("\\", "\\\\") + "\"," + "\n")
        except:
            bName = "None"
            self.jsonfile.write("{ \"Build Name\" : \"" + bName + "\"," + "\n")
        self.jsonfile.write("\"Build Id\" : \"" + bID.replace("\\", "\\\\") + "\"," + "\n")
        self.jsonfile.write("\"ArtSize\" : \"" + size + "\"}" + "\n")

    def getSmartAllBuildsArtsize(self, rootProjectID, info, date):

        directBuilds = TC.Teamcity.getBuildsDirectlyFromProject(TC.Teamcity, rootProjectID)
        subProjects = TC.Teamcity.getSubprojectsFromProject(TC.Teamcity, rootProjectID)
        if rootProjectID not in self.projectsArtSize.keys():

            try:
                subProjectsCount = len(subProjects)
            except TypeError as e:
                subProjectsCount = 0
            buildsSize = 0
            builds = []
            if directBuilds == 0:
                pass
            else:
                for dBuild in directBuilds:

                    if dBuild not in self.buildsArtSize.keys():
                        buildsSizeL = 0
                        # todo : get last build date only
                        lastBuildTCDates = ["20000101T000000+0300","20000101T000000+0300"]
                        lastBuildDates = ["2000-01-01-00-00","2000-01-01-00-00"]
                        lastNPBuild = TC.Teamcity.getLastBuildsByCount(self,dBuild,1, personal="false")
                        if lastNPBuild != [] :
                            lastBuildTCDates[0] = TC.Teamcity.getBuildFinishDate(TC.Teamcity, buildId=lastNPBuild[0])


                        lastPBuild= TC.Teamcity.getLastBuildsByCount(self,dBuild,1, personal="true")
                        if lastPBuild != []:
                            lastBuildTCDates[1] = TC.Teamcity.getBuildFinishDate(TC.Teamcity, buildId=lastPBuild[0])

                        lastBuildDates[0] = TC.Teamcity.getDateFromTCDate(TC.Teamcity, lastBuildTCDates[0])

                        lastBuildDates[1] = TC.Teamcity.getDateFromTCDate(TC.Teamcity, lastBuildTCDates[1])

                        comp = self.dateComparer(self,firstDate=lastBuildDates[0],secondDate=lastBuildDates[1])

                        if comp > 0 :
                            newer =  lastBuildDates[1]
                        else :
                            newer =  lastBuildDates[0]
                        # check whether existing data is newer than last build
                        repDate = datetime.datetime(int(date[:4]),int(date[5:7]),int(date[8:10]),int(date[11:13]),int(date[14:16]),int(date[17:19]))
                        comp = self.dateComparer(self,firstDate= newer,secondDate= repDate)

                        if comp > 0 :

                            t = info.get_node(dBuild)
                            buildsSizeL = int(float(t.data.artSize[:-4])*1048576)
                            self.buildsArtSize[dBuild] = buildsSizeL
                            buildsSize += buildsSizeL
                            pass
                            #no need to get info from TC, getting it from data

                        else :

                            builds = TC.Teamcity.getListOfBuildsByCountAndDate(TC.Teamcity,dBuild, count=16, date=8)
                            acc = 0
                            build_s = ""
                            with joblib.Parallel(n_jobs=8, backend="threading") as parallel:

                                build_s = parallel(joblib.delayed(TC.Teamcity.getArtifactsSizeById)(TC.Teamcity,build) for build in builds)

                                for i in build_s: acc += int(i)
                                buildsSizeL += acc
                            self.buildsArtSize[dBuild] = buildsSizeL
                            buildsSize += buildsSizeL
                    else:
                        buildsSize = self.buildsArtSize[dBuild]
            if subProjectsCount == 0 :
                pass
            else:
                #for subP in subProjects:
                    #    t = self.getSmartAllBuildsArtsize(self,subP, info= info, date= date)
                    #    buildsSize += int(t)

                acc = 0
                with joblib.Parallel(n_jobs=8, backend="threading") as parallel:

                    build_s = parallel(
                        joblib.delayed(self.getSmartAllBuildsArtsize)(self, subP,info, date) for subP in subProjects)

                    for i in build_s: acc += int(i)
                    buildsSize += acc
            self.projectsArtSize[rootProjectID] = buildsSize
        else:
            buildsSize = self.projectsArtSize[rootProjectID]
        return buildsSize




    def projectToJSON(self,rootProjectID):
        prID = rootProjectID
        prName = TC.Teamcity.getProjectNameById(TC.Teamcity, rootProjectID)
        subPR =TC.Teamcity.getSubprojectsFromProject(TC.Teamcity, rootProjectID)

        dBuilds = self.getNodesDirectLeaves(self, self.tree, rootProjectID)
        ArtSize = (self.tree.get_node(rootProjectID)).data.artSize
        self.jsonfile.write("{ \"Project Name\" : \"" + prName.replace("\\", "\\\\") + "\"," + "\n")
        self.jsonfile.write("\"Project Id\" : \"" + prID.replace("\\", "\\\\") + "\"," + "\n")
        self.jsonfile.write("\"ArtSize\" : \"" + ArtSize + "\"," + "\n")

        if subPR:
            self.jsonfile.write("\"SubProjects\" : [" + "\n")
            count = 0
            for sp in subPR:
                count +=1
                self.projectToJSON(self, sp)
                if count != len(subPR):
                    self.jsonfile.write ("," + "\n")
            self.jsonfile.write("],")
        else:
            self.jsonfile.write("\"SubProjects\" : \"None\"," + "\n")
        if dBuilds:
            self.jsonfile.write(("\"directBuilds\" : [") + "\n")
            c = 0
            for db in dBuilds:
                c +=1
                self.buildToJSON(self, db)
                if c != len(dBuilds):
                    self.jsonfile.write("," + "\n")

            self.jsonfile.write("]")
        else:
            self.jsonfile.write("\"directBuilds\" : \"None\"" + "\n")
        self.jsonfile.write ("}" + "\n")

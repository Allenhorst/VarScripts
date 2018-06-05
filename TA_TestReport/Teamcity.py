import os
import requests
import json
import datetime

class Teamcity:
    username = None
    password = None
    server = "http://vmsk-tc-prm.paragon-software.com"
    port = None
    error_handler = None
    auth = None
    session = None

    def __init__(self, username=None, password=None, server=None, port=None,
                 session=None, protocol=None):
        self.agentName = os.getenv('AgentName')
        self.username = username or os.getenv('TEAMCITY_USER')
        self.password = password or os.getenv('TEAMCITY_PASSWORD')
        self.host = server or os.getenv('TEAMCITY_HOST')
        self.port = port or int(os.getenv('TEAMCITY_PORT', 0)) or 80
        self.protocol = protocol or os.getenv('TEAMCITY_PROTOCOL', 'http')
        self.base_base_url = "%s://%s:%d" % (
            self.protocol, self.host, self.port)
        self.guest_auth_base_url = "%s://%s:%d/guestAuth" % (
            self.protocol, self.host, self.port)
        if self.username and self.password:
            self.base_url = "%s://%s:%d/httpAuth/app/rest" % (
                self.protocol, self.host, self.port)
            self.auth = (self.username, self.password)
        else:
            self.base_url = "%s://%s:%d/guestAuth/app/rest" % (
                self.protocol, self.host, self.port)
            self.auth = None
        self.session = session or requests.Session()
        self._agent_cache = {}

### requests past
    def _send_request(self, request):
        try:
            return self.session.send(request)
        except requests.exceptions.ConnectionError as e:
            new_exception = ConnectionError(self.host, self.port, e)
            if self.error_handler:
                self.error_handler(new_exception)
            else:
                raise new_exception

    def _prep_request(self, verb, url, headers=None, **kwargs):
        if headers is None:
            headers = {'Accept': 'application/json'}
        return requests.Request(
            verb,
            url,
            auth=self.auth,
            headers=headers,
            **kwargs).prepare()

### date converting part
    def getTCDateFromDate(self, date):
        TCNow = str(date.year).zfill(2)+str(date.month).zfill(2)+str(date.day).zfill(2)+"T"+str(date.hour).zfill(2)+str(date.minute).zfill(2)+str(date.second).zfill(2)+"%2B0300"
        return TCNow

    def getDateFromTCDate(self,TCDate):
        now = datetime.datetime(year=int(TCDate[0:4]), month=int(TCDate[4:6]), day=int(TCDate[6:8]), hour=int(TCDate[9:11]), minute=int(TCDate[11:13]), second=int(TCDate[13:15]))
        return now


    def getBuildByBuildId(self, buildId):

        buildUrl = self.server + "/" + "httpAuth/app/rest/builds/?locator=buildType:" + buildId
        buildReq = self._prep_request(self,verb="GET", url=buildUrl)
        buildsList = self._send_request(self, buildReq)
        print(buildsList.json())

        return 0

    # uses build id directly to get build
    def getBuildById(self, Id):
        buildUrl = self.server + "/" + "httpAuth/app/rest/builds/id:" + Id
        buildReq = self._prep_request(self, verb="GET", url=buildUrl)
        build = self._send_request(self, buildReq)
        # print(buildsList.json())

        return build.text

    # uses build type to get last successful build of this type
    def getLastSuccessfulBuildById(self, buildId):
        buildUrl = self.server + "/" + "httpAuth/app/rest/builds/?locator=buildType:" + buildId + ",status:success,count:1"
        buildReq = self._prep_request(self, verb="GET", url=buildUrl)
        buildsList = self._send_request(self, buildReq)
        buildDict = json.loads(buildsList.text)
        # print(buildDict)
        buildList = (buildDict['build']).pop()
        buildWebUrl = buildList['webUrl']
        buildId = buildList['id']
        build = self.getBuildById(self, Id=str(buildId))
        # print(buildWebUrl)
        # print(build.json())

        return 0

    def getAgentIdByName(self, name):
        agentUrl = self.server + "/" + "httpAuth/app/rest/agents/name:" + name
        agentReq = self._prep_request(self, verb="GET", url=agentUrl)
        agent = self._send_request(self, agentReq)
        agentDict = json.loads(agent.text)
        agentId = agentDict['id']

        return agentId

    def getInformationFromBuild(self, buildText):
        buildInf = json.loads(buildText)
        buildWebUrl = buildInf['webUrl'].split('&')[0]
        buildName = buildInf['buildType']['name']
        # buildName1 = buildName0['name']
        buildVer = buildInf['number'].split('(')[1].split(')')[0]
        # print(buildWebUrl)
        # print(buildName)
        # print(buildVer)
        return buildWebUrl, buildName, buildVer

    def getBuildNameByBuildId(self, buildId):
        buildUrl = self.server + "/" + "httpAuth/app/rest/buildTypes/?locator=id:" + buildId
        buildReq = self._prep_request(self, verb="GET", url=buildUrl)
        buildList = self._send_request(self, buildReq)
        buildInf = json.loads(buildList.text)
        try:
            buildName = (buildInf['buildType'].pop())['name']
        except:
            buildName = None
        return buildName

    def getBuildRequirementsByBuildId(self, buildId):
        buildUrl = self.server + "/" + "httpAuth/app/rest/buildTypes/id:" + buildId + "/agent-requirements/"
        buildReq = self._prep_request(self, verb="GET", url=buildUrl)
        buildList = self._send_request(self, buildReq)
        buildInf = json.loads(buildList.text)
        t1 = (buildInf['properties'].pop())
        return buildInf

    def getCompatibleAgentsForBuild(self, buildId):
        buildUrl = self.server + "/" + "httpAuth/app/rest/agents?locator=compatible:(buildType:(id:" + buildId + ")),enabled:any"
        buildReq = self._prep_request(self, verb="GET", url=buildUrl)
        buildList = self._send_request(self, buildReq)
        agents = json.loads(buildList.text)
        agentsList = []
        if agents['count'] != 0:
            count = agents['count']
            while count:
                agent = (agents['agent']).pop()['name']
                agentsList.append(agent)
                count -= 1

        else:
            agentsList = 0
        return agentsList

    def getArtifactsSizeById(self, buildId):
        buildUrl = self.server + "/" + "httpAuth/app/rest/builds/id:" + str(buildId) + "/artifacts"
        buildReq = self._prep_request(self, verb="GET", url=buildUrl)
        buildList = self._send_request(self, buildReq)
        files = json.loads(buildList.text)
        if files['count'] != 0:
            buildUrl = self.server + "/" + "httpAuth/app/rest/builds/id:" + str(buildId) + "/statistics/VisibleArtifactsSize"
            buildReq = self._prep_request(self, verb="GET", url=buildUrl, headers={'Accept': 'text/plain'})
            buildList = self._send_request(self, buildReq)
            if buildList.status_code != 200:
                #buildUrl = self.server + "/" + "httpAuth/app/rest/builds/id:" + str(buildId) + "/statistics/ArtifactsSize"
                #buildReq = self._prep_request(self, verb="GET", url=buildUrl, headers={'Accept': 'text/plain'})
                #buildList = self._send_request(self, buildReq)
                return 0
            return buildList.text
        else:
            return 0

    #tillDays - number of days in past
    def getLastBuildsByDate(self, buildId, tillDays, personal="false"):
        now = datetime.datetime.now()
        till = now - datetime.timedelta(tillDays)
        tcTill = self.getTCDateFromDate(self,till)
        buildUrl = self.server + "/" + "httpAuth/app/rest/builds/?locator=buildType:" + buildId + ",status:SUCCESS" + ",finishDate:(date:" + tcTill + ",condition:before),personal:" + personal
        buildReq = self._prep_request(self, verb="GET", url=buildUrl)
        buildsList = self._send_request(self, buildReq)
        buildDict = json.loads(buildsList.text)
        builds = []
        if buildDict['count'] !=0 :
            for build in buildDict['build']:
                buildId = build['id']
                builds.append(buildId)

        return builds

    def getLastBuildsByCount(self,buildId, count, personal="false"):
        buildUrl = self.server + "/" + "httpAuth/app/rest/builds/?locator=buildType:" + buildId + ",status:success,count:" +str(count) + ",personal:" + personal
        buildReq = self._prep_request(self, verb="GET", url=buildUrl)
        buildsList = self._send_request(self, buildReq)
        buildDict = json.loads(buildsList.text)
        builds = []
        if buildDict['count'] != 0:
            for build in buildDict['build']:
                buildId = build['id']
                builds.append(buildId)
        return builds

    def getListOfBuildsByCountAndDate(self, buildId, count , date):
        builds = []
        b = self.getLastBuildsByDate(self,buildId, date, personal="false")
        builds += b
        b = self.getLastBuildsByDate(self,buildId, date, personal="true")
        builds += b
        b = self.getLastBuildsByCount(self,buildId, count, personal="false")
        builds += b
        b = self.getLastBuildsByCount(self,buildId, count, personal="true")
        builds += b
        return list(set(builds))
    # by given buildId return ID of last successful build of this type on given agent
    def getLastSuccessfulBuildByIdAndagent(self, buildId, agentName):
        buildUrl = self.server + "/" + "httpAuth/app/rest/builds/?locator=buildType:" + buildId + ",agentName:" + agentName + ",status:SUCCESS" + ",sinceDate:20170720T000000%2B0300"
        buildReq = self._prep_request(self, verb="GET", url=buildUrl)
        buildList = self._send_request(self, buildReq)
        buildDict = json.loads(buildList.text)
        if buildDict['count'] != 0:

            buildList = (buildDict['build']).pop()
            buildWebUrl = (buildList['webUrl']).split('&')[0]
            Id = buildList['id']
        else:
            Id = 0
        return Id

    def getBuildsDirectlyFromProject(self, projectId):
        projectUrl = self.server + "/" + "httpAuth/app/rest/projects/id:" + projectId
        projectReq = self._prep_request(self, verb="GET", url=projectUrl)
        projectList = self._send_request(self, projectReq)
        projectDict = json.loads(projectList.text)
        builds = []
        if projectDict['buildTypes']['count'] == 0:
            return 0
        else:
            for build in projectDict['buildTypes']['buildType']:
                buildId = build['id']
                builds.append(buildId)
            return builds

  # project related requests

    def getProjectById(self, projectId):
        projectUrl = self.server + "/" + "httpAuth/app/rest/projects/id:" + projectId
        projectReq = self._prep_request(self, verb="GET", url=projectUrl)
        project = self._send_request(self, projectReq)
        print(project.json())
        return 0

    def getAllBuildTypesForProject(self,projectId):
        buildIds = []
        buildUrl = self.server + "/" + "httpAuth/app/rest/buildTypes?locator=affectedProject:(id:" + projectId + \
                   ")&fields=buildType(id,name,builds($locator(personal:any,running:false,canceled:false,count:1),build(number,status,statusText)))"
        buildReq = self._prep_request(self, verb="GET", url=buildUrl)
        buildList = self._send_request(self, buildReq)
        buildDict = json.loads(buildList.text)
        buildList = (buildDict['buildType'])
        #try :
        #    buildList = (buildDict['buildType']).pop()
        #
        #except Error as e:
        for build in buildList:
            buildId = build['id']
            buildIds.append(buildId)

        return buildIds

    def getAllBuildTypesForProjectNames(self,projectId):
        buildIds = []
        buildUrl = self.server + "/" + "httpAuth/app/rest/buildTypes?locator=affectedProject:(id:" + projectId + \
                   ")&fields=buildType(id,name,builds($locator(personal:any,running:false,canceled:false,count:1),build(number,status,statusText)))"
        buildReq = self._prep_request(self, verb="GET", url=buildUrl)
        buildList = self._send_request(self, buildReq)
        buildDict = json.loads(buildList.text)
        buildList = (buildDict['buildType'])
        #try :
        #    buildList = (buildDict['buildType']).pop()
        #
        #except Error as e:
        for build in buildList:
            buildId = build['name']
            buildIds.append(buildId)

        return buildIds

    def getSubprojectsFromProject(self, projectId):
        projectUrl = self.server + "/" + "httpAuth/app/rest/projects/id:" + projectId
        projectReq = self._prep_request(self, verb="GET", url=projectUrl)
        projectList = self._send_request(self, projectReq)
        projectDict = json.loads(projectList.text)
        projects = []
        if projectDict['projects']['count'] == 0:
            return 0
        else:
            for project in projectDict['projects']['project']:
                projectId = project['id']
                projects.append(projectId)
            return projects

    def summarizeArtifactSizeForProject(self, projectId):

        return 0# buildsArtSize + projectsArtSize

    def getParentProject(self, projectId):
        projectUrl = self.server + "/" + "httpAuth/app/rest/projects/id:" + projectId
        projectReq = self._prep_request(self, verb="GET", url=projectUrl)
        projectList = self._send_request(self, projectReq)
        projectDict = json.loads(projectList.text)

        return projectDict['parentProjectId']

    def getProjectNameById(self, projectId):
        projectUrl = self.server + "/" + "httpAuth/app/rest/projects/id:" + projectId
        projectReq = self._prep_request(self, verb="GET", url=projectUrl)
        projectList = self._send_request(self, projectReq)
        projectDict = json.loads(projectList.text)

        return projectDict['name']

    def getBuildFinishDate(self,buildId):
        buildUrl = self.server + "/" + "httpAuth/app/rest/builds/id:" + str(buildId)
        buildReq = self._prep_request(self, verb="GET", url=buildUrl)
        buildList = self._send_request(self, buildReq)
        buildDict = json.loads(buildList.text)
        finishDate = buildDict['finishDate']
        return finishDate
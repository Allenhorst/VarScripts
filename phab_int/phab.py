from phabricator import Phabricator
import json

class Phab:
    url = None
    api_token = None
    phabricator = None

    def __init__(self, url=None, api_token=None):
        self.url = url
        self.api_token = api_token
        self.phabricator = Phabricator(host=self.url, token=self.api_token)

    # build json from given data
    def buildTransaction(self,data):
        return json.dumps(data)

    def buildCallsign(self, name):

        cn = []
        for word in name.split():
            if word.isupper() or word.isdigit():
                cn.append(word)
            else:
                pass
        return str(cn)


    # get PHID from user alias AKA short name
    def findUser(self, user_alias=None):
        result = (self.phabricator.user.find(aliases=[user_alias]))
        if result.response == []:
            raise Exception("Failed to find user " + user_alias + " , please check given name")
        resp = result.response[user_alias]
        return str(resp)

    def createProject(self, name=None, members=None, view=None, edit=None, join=None ):
        data = []

        if name:
            _name = {"type": "name", "value": name}
            data.append(_name)

        if members:
            _list_members = []
            for member in members:
                _list_members.append(member)
            _members = {"type": "members.add", "value": _list_members}
            data.append(_members)

        if view:
            _view = {"type": "view", "value": view}
            data.append(_view)

        if edit:
            _edit = {"type": "edit", "value": edit}
            data.append(_edit)

        if join:
            _join = {"type": "join", "value": join}
            data.append(_join)
        try:
            result = (self.phabricator.project.edit(transactions=data))
            projectPHID = result.response['object']['phid']
            print(str(projectPHID))
        except:
            raise Exception("Failed to create or change project" + name + "Error message: " + str(result.response))


        return projectPHID

    def createRepository(self,vcs=None, name=None, callsign=None,shortName=None, 
                         status=None, projects=None):
        data = []

        if vcs:
            _vcs = {"type": "vcs", "value": vcs}
            data.append(_vcs)
            
        if name:
            _name = {"type": "name", "value": name}
            data.append(_name)

        if callsign:
            _callsign = {"type": "callsign", "value": callsign}
            data.append(_callsign)

        if shortName:
            _shortName = {"type": "shortName", "value": shortName}
            data.append(_shortName)

        if status:
            _status = {"type": "status", "value": status}
            data.append(_status)

        if projects:
            _list_projects = []
            for project in projects.split(","):
                _list_projects.append(project)
            _projects = {"type": "projects.add", "value": _list_projects}
            data.append(_projects)
        try:
            result = (self.phabricator.diffusion.repository.edit(transactions=data))
            repositoryPHID = result.response['object']['phid']
            print(str(repositoryPHID))
            return repositoryPHID
        except:
            raise Exception("Failed to create or change repository" + name + "Error message: " + str(result.response))



    def createURI(self,repo=None, uri=None, io=None, display=None, creds=None, disable=None):
        data = []
        if repo:
            _repo = {"type": "repository", "value": repo}
            data.append(_repo)
        if uri:
            _uri = {"type": "uri", "value": uri}
            data.append(_uri)
        if io:
            _io = {"type": "io", "value": io}
            data.append(_io)
        if display:
            _display = {"type": "display", "value": display}
            data.append(_display)
        if creds:
            _creds = {"type": "creds", "value": creds}
            data.append(_creds)
        if disable:
            _disable = {"type": "disable", "value": disable}
            data.append(_disable)

        try:
            result = (self.phabricator.diffusion.uri.edit(transactions=data))
            uriPHID = result.response['object']['phid']
            print(str(uriPHID))
            return uriPHID
        except:
            raise Exception("Failed to create or change URI for repository " + repo + "Error message: " + str(result.response))

    def createPackage(self, name=None, owners=None, dominion=None, autoReview=None, auditing=None, description=None, 
                      status=None, paths_set=None, view=None, edit=None):

        data = []
        if name:
            _name = {"type": "name", "value": name}
            data.append(_name)
        if owners:
            _owners = {"type": "owners", "value": owners}
            data.append(_owners)
        if dominion:
            _dominion = {"type": "dominion", "value": dominion}
            data.append(_dominion)
        if autoReview:
            _autoReview = {"type": "autoReview", "value": autoReview}
            data.append(_autoReview)
        if auditing:
            _auditing = {"type": "auditing", "value": auditing}
            data.append(_auditing)
        if description:
            _description = {"type": "description", "value": description}
            data.append(_description)
        if status:
            _status = {"type": "status", "value": status}
            data.append(_status)
        if paths_set:
            _paths_set = {"type": "paths_set", "value": paths_set}
            data.append(_paths_set)
        if view:
            _view = {"type": "view", "value": view}
            data.append(_view)
        if edit:
            _edit = {"type": "edit", "value": edit}
            data.append(_edit)

        try:
            result = (self.phabricator.owners.edit(transactions=data))
            ownersPHID = result.response['object']['phid']
            print(str(ownersPHID))
            return ownersPHID
        except:
            raise Exception("Failed to create or change owners package" + name + "Error message: " + str(result.response))

    def createBlog(self, name=None, subtitle=None, description=None):
        data = []
        if name:
            _name = {"type": "name", "value": name}
            data.append(_name)
        
        if subtitle:
            _subtitle = {"type": "subtitle", "value": subtitle}
            data.append(_subtitle)
            
        if description:
            _description = {"type": "description", "value": description}
            data.append(_description)
            
        try:
            result = self.phabricator.phame.blog.edit(transactions=data)
            phamePHID = result.response['object']['phid']
            print(str(phamePHID))
            return phamePHID
        except:
            raise Exception("Failed to create or change owners package" + name + "Error message: " + str(result.response))






from phabricator import Phabricator
import json
import ssh
import phab
import cldap
import time







CONDUIT_API_TOKEN = "api-5wcqxxtr267524yn2eg7to62ckqz"
URL = "http://phab-vc60-pkt.paragon-software.com/api/"
POLICY_VIEW = "PHID-PLCY-qekrh5ekttym6zarofsr"
POLICY_EDIT = "PHID-PLCY-2few5pea5hysj3bfiqm7"
POLICY_JOIN = "admin"

searchPeople = json.dumps({"queryKey": "active", "order": "newest", "data" : "username"})
#phab = Phabricator(host='http://phab-vc60-pkt.paragon-software.com/api/', token='api-5wcqxxtr267524yn2eg7to62ckqz')
##phab.update_interfaces()#
#t = str(phab.user.find#
#print (t)
users = []
ph = phab.Phab(URL, CONDUIT_API_TOKEN)






#t = ph.findUser("Ptester")
#user = ph.findUser("Ptester")
#users.append(user)
#t = ph.createProject(name="test_policy_3", members=user, view=POLICY_VIEW, edit=POLICY_EDIT, join=POLICY_JOIN)

#t = ph.createRepository(vcs="git", name="test_repo_1", callsign="TRPI", shortName="test_repo_1", status="active",
#                        projects="PHID-PROJ-5nsat55rsw35eyghaxaa")

#t = ph.createPackage(name="test_package_4", owners=users, dominion="strong", autoReview="block", auditing=None, description=None,
#                     status="active", paths_set=None, view="users", edit="users")



# main scenario
# input parameters
usersToAdd = ["AAAAA", "Ptester"]
projectName = "TestFull5"

ad = cldap.CLDAP()
group_exists = ad.checkGroup(group="test")
if not group_exists:
    print("At least one of AD groups not found")
    exit(-1)

time.sleep(2)
ssh = ssh.SSH()
ssh.exec_script(repo=projectName)

# Step 1 : get users id from given names


users = []
for user in usersToAdd:
    try:
        _user = ph.findUser(user)
    except Exception as e:
        print("Error message : " + str(e))
        continue
    users.append(_user)
for i in users:
    print(i)
# Step 2 : create project with given name and members
try:
    project = ph.createProject(name=projectName, members=users, view=POLICY_VIEW, edit=POLICY_EDIT, join=POLICY_JOIN)
except Exception as e:
    print("Failed to create project. Error message :" + str(e))
    exit(-1)

# Step 3 : create Repository in diffusion
try:
    repository = ph.createRepository(vcs="git", name=projectName, status="active",
                                     projects=project)
except Exception as e:
    print("Failed to create repository. Error message :" + str(e))
    exit(-1)

# Step 4 : create URI
try:
    uri = ph.createURI(repo=repository, uri="ssh://phab-vc60-pkt@phab-vc60-pkt/git/test.repo.1.git", io="observe")
except Exception as e:
    print("Failed to create repository URI. Error message :" + str(e))
    exit(-1)

# Step 5 : create Package
try:
    uri = ph.createPackage(name=projectName, owners=users, dominion="strong", autoReview="block", status="active",
                           paths_set=None, view="users", edit="users")
except Exception as e:
    print("Failed to create package. Error message :" + str(e))
    exit(-1)

# Step 6 : create Blog
try:
    uri = ph.createBlog(name=projectName, subtitle=projectName, description="  ")
except Exception as e:
    print("Failed to create Blog. Error message :" + str(e))
    exit(-1)

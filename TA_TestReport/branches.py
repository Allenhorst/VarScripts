import Teamcity as TC
import os
import sys

allBuildIds = []
allBuildNames = []
allTestsProjectIds = ["Prm_Tests_L1", "Prm_Tests_L2", "Prm_Tests_L3", "Prm_Tests_Newfn"]
excludeProjectIds = ["Investigate", "Legacy"]  # to do add real id
defaultAgentId = "ta-srv1112-14"
try:
    agentId = sys.argv[1]
except IndexError as e:
    agentId = defaultAgentId



TC.Teamcity.__init__(TC.Teamcity, username="adacc",
                     password="jd7gowuX",
                     server="http://vmsk-tc-prm.paragon-software.com",
                     port=None
                     )

buildId = "2258989"
size = TC.Teamcity.getArtifactsSizeById(TC.Teamcity, buildId)

print (size)









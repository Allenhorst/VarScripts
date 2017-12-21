from ldap3 import *

class CLDAP:

    AD_SERVER = "172.30.66.64"
    # AD_SERVER = "winsrv-vc60-pkt.infr.local"
    AD_USER = "INFR\git_ad"
    AD_PASSWORD = "Qaz1234"
    server = None
    conn = None
    def __init__(self):
        self.server = Server(self.AD_SERVER, get_info=ALL)
        self.conn = Connection(self.server, user=self.AD_USER, password=self.AD_PASSWORD, authentication=NTLM)
        self.conn.bind()

    def buildgroupFilter(self, fgroup=None):
        return "(&(objectClass=group)(name=dl_git_{}_ro))".format(fgroup)

    def checkGroup(self, group):
        _group = group
        gr = self.buildgroupFilter(fgroup=_group)

        rw_group = self.conn.search('dc=infr,dc=local', gr)
        if rw_group:
            print(self.conn.entries[0].entry_dn)
            return True
        else:
            print("Group %s not found in AD, please check its existence", group)
            return False





from ldap3 import *

class LDAP:

    AD_SERVER = "172.30.66.64"
    # AD_SERVER = "winsrv-vc60-pkt.infr.local"
    AD_USER = "INFR\git_ad"
    AD_PASSWORD = "Qaz1234"
    server, conn = None
    def __init__(self):
        self.server = Server(self.AD_SERVER, get_info=ALL)
        self.conn = Connection(self.server, user=self.AD_USER, password=self.AD_PASSWORD, authentication=NTLM)
        self.conn.bind()

    def buildgroupFilter(group=None):
        return "(&(objectClass=group)(name={}))".format(group)

    def checkGroup(self, group):

        res = self.conn.extend.standard.who_am_i()
        gr = self.buildgroupFilter(group)

        rw_group = self.conn.search('dc=infr,dc=local', gr)
        if rw_group:
            print(self.conn.entries.entry_dn)
        else:
            print("Group %s not found in AD, please check its existence", group)
        print(rw_group)
        print(res)




import paramiko
import time
class SSH():

    client = None
    def __init__(self):

        self.client = paramiko.SSHClient()
        self.client.set_missing_host_key_policy(paramiko.AutoAddPolicy())

        self.client.connect(hostname="172.30.66.70", username="admin", password="Qwerty123", port=22)
        #stdin, stdout, stderr = client.exec_command('ls -l')
        #data = stdout.read() + stderr.read()
        #print (data)
        #b'total 0\ndrwxr-xr-x. 2 admin admin 6 Dec 20 13:30 Desktop\ndrwxr-xr-x. 2 admin admin 6 Dec 20 13:30 Documents\ndrwxr-xr-x. 2 admin admin 6 Dec 20 13:30 Downloads\ndrwxr-xr-x. 2 admin admin 6 Dec 20 13:30 Music\ndrwxr-xr-x. 2 admin admin 6 Dec 20 13:30 Pictures\ndrwxr-xr-x. 2 admin admin 6 Dec 20 13:30 Public\ndrwxr-xr-x. 2 admin admin 6 Dec 20 13:30 Templates\ndrwxr-xr-x. 2 admin admin 6 Dec 20 13:30 Videos\n'
        #stdin, stdout, stderr = client.exec_command('cd /opt/git')
        #data = stdout.read() + stderr.read()

    def exec_script(self,repo):
        stdin, stdout, stderr = self.client.exec_command(('sudo /opt/git/git.sh {}').format(repo), get_pty=True)
        time.sleep(1)
        stdin.write('Qwerty123' + '\n')
        stdin.flush()
        data = stdout.read() + stderr.read()
        print(data)
        return 0




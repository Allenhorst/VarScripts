import loader
import DiskUsage
import treelib

class Reporter():
    row = ""
    def indent(level):
        return "&emsp;"*level*2

    def buildReport(self, new, old):
        diff = {}
        for node_new in new.all_nodes():
            try:
                node_old = old.get_node(node_new.identifier)
                if (node_old == None):
                    diff[node_new.identifier] = "None"
                else:
                    oldsize = node_old.data.artSize
                    oldsize1 = node_old.data.artSize[0:(len(oldsize)-5)]
                    oldsize2 = float(oldsize1)
                    oldsize = float(node_old.data.artSize[0:(len(node_old.data.artSize)-5)])
                    newsize = float(node_new.data.artSize[0:(len(node_new.data.artSize)-5)])
                    if oldsize == 0.0:
                        diff[node_new.identifier] = 0.0
                    else:
                        diff[node_new.identifier] = (newsize-oldsize)/oldsize
            except:
                print("Unexpected error within node" + node_new.name)
        return diff

    def generateReport(self,new, level_cap):
        diff = {}
        cur_level = 0
        root = new.get_node( new.root)
        text = self.buildStr(self,new,root,cur_level,level_cap)

        return text

    def generateCompReport(self,new,old, level_cap):
        diff = self.buildReport(self, new=new, old=old)
        cur_level = 0
        root = new.get_node( new.root)
        text = self.buildComp(self,root,new,diff ,cur_level,level_cap)

        return text

    def buildStr(self,tree,node,level, level_cap, row=""):
        self.row =row
        if level > level_cap :
            return self.row
        else:
            cur_level = level
            artSize = node.data.artSize
            try:
                prName = node.data.name["Build Name"]
            except:
                prName = node.data.name
            subPr = tree.children(node.identifier)
            #dirBuilds = node.data

            hLvl = lambda level : level+1 if level < 6 else 6
            self.row += "<tr>" + "<td valign=top><h"+str(hLvl(cur_level))+">" +self.indent(cur_level)  + node.tag + "(" + node.identifier + ") " +  "</h"+str(hLvl(cur_level))+">"+ "</td><td>" + artSize + "</td></tr>\n"
        if subPr != "None":
            for subP in subPr:
                self.buildStr(self,tree,subP,level=cur_level+1, level_cap=level_cap, row=self.row)

        # "<tr> <td valign=top>" + buildName + "</td></tr>"
        return self.row

    def buildComp(self, node,tree, diff, level, level_cap, row=""):
        self.row = row
        if level > level_cap:
            return self.row
        else:
            cur_level = level
            artSize = node.data.artSize
            try:
                prName = node.identifier
            except:
                prName = node.data.name
            subPr = tree.children(node.identifier)
            # dirBuilds = node.data

            hLvl = lambda level: level + 1 if level < 6 else 6
            self.row += "<tr>" + "<td valign=top><h" + str(hLvl(cur_level)) + ">" + self.indent(cur_level) +  node.tag + "(" + node.identifier + ") "+ "</h" + str(hLvl(cur_level)) + ">" + "</td><td>" + str(diff[prName]) + "</td></tr>\n"
        if subPr != "None":
            for subP in subPr:
                self.buildComp(self,subP, tree,diff, level=cur_level + 1, level_cap=level_cap, row=self.row)

        # "<tr> <td valign=top>" + buildName + "</td></tr>"
        return self.row
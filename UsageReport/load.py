import loader

L = loader.Loader("tree.json")
js = L.parseJson("tree.json")
t = L.addProjectNode(js)
print(t)
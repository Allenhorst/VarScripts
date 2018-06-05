import pstats
t = pstats.Stats()
t.add("D:\\Scripts\\UsageReport\\prof.txt")
t.sort_stats("cumtime")
t.print_stats(0.1)

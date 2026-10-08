"""Extract real closed edge cycles; never bridge open endpoints."""
import json,sys
from collections import defaultdict
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
report=json.loads((ROOT/(sys.argv[1] if len(sys.argv)>1 else "build/sever_boundary_review.json")).read_text(encoding="utf-8"))
odd_boundaries="--odd-boundaries" in sys.argv[3:]
if odd_boundaries:
 report["boundary_mode"]="Odd edge incidence: overlapping closed surface pairs cancel; remaining odd incidence supplies contour candidates only, not topology approval."
for cut in report["cuts"]:
 for region in cut["regions"]:
  if odd_boundaries:
   boundaries=set(region.get("all_boundary_edges",region["edges"]))
   new=set(region["edges"])
   for edge,counts in region.get("nonmanifold_edges",{}).items():
    if counts["after"] % 2:
     boundaries.add(edge)
     if counts["before"] % 2 == 0: new.add(edge)
   region["all_boundary_edges"]=sorted(boundaries)
   region["edges"]=sorted(new)
   region["new_open_edges"]=len(new)
  graph=defaultdict(set)
  for edge in region.get("all_boundary_edges",region["edges"]):
   a,b=edge.split("|");graph[a].add(b);graph[b].add(a)
  visited=set();active=[];cycles=[]
  def visit(vertex,parent=None):
   visited.add(vertex);active.append(vertex)
   for neighbor in sorted(graph[vertex]):
    if neighbor==parent:continue
    if neighbor not in visited:visit(neighbor,vertex)
    elif neighbor in active:
     start=active.index(neighbor)
     if start<len(active)-2:cycles.append(active[start:].copy())
   active.pop()
  for vertex in sorted(graph):
   if vertex not in visited:visit(vertex)
  new_edges={tuple(sorted(edge.split("|"))) for edge in region["edges"]}
  cycles=[cycle for cycle in cycles if any(tuple(sorted((a,cycle[(i+1)%len(cycle)]))) in new_edges for i,a in enumerate(cycle))]
  used=set()
  for cycle in cycles:
   for i,a in enumerate(cycle):used.add(tuple(sorted((a,cycle[(i+1)%len(cycle)]))))
  all_edges={tuple(sorted(edge.split("|"))) for edge in region["edges"]}
  unresolved=all_edges-used
  region["closed_loops"]=[[[int(n)/10000 for n in vertex.split(",")] for vertex in cycle] for cycle in cycles]
  region["ambiguous_components"]=[len(unresolved)] if unresolved else []
  region["unresolved_edges"]=["|".join(edge) for edge in sorted(unresolved)]
  print(cut["look"],cut["part"],"cycles",len(cycles),"unresolved edges",len(unresolved))
(ROOT/(sys.argv[2] if len(sys.argv)>2 else "build/sever_wound_loops.json")).write_text(json.dumps(report,indent=2),encoding="utf-8")

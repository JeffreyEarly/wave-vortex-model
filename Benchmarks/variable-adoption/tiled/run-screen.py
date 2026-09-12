import subprocess,json,pathlib,sys,time,statistics,hashlib
binary=sys.argv[1];root=pathlib.Path(sys.argv[2]);phase=sys.argv[3];out=root/phase;out.mkdir(exist_ok=False)
# No modifications to other processes; wait for a quiet host before the campaign.
for attempt in range(12):
 time.sleep(10)
 ps=subprocess.check_output(['ps','-axo','pid=,pcpu=,comm='],text=True)
 busy=[line for line in ps.splitlines() if float(line.split(None,2)[1])>10]
 (out/f'preflight-{attempt}.txt').write_text(ps)
 if not busy: break
else: raise SystemExit('Host did not become idle; no timing run started')
if phase=='pilot':
 cases=[(family,nz,tile,share,0) for family,nz in [('hydro',28),('bouss',129)] for tile in [1,4,16] for share in [0,1]]
 samples=5
else:
 tile=int(sys.argv[4]);share=int(sys.argv[5]);samples=9
 cases=[(family,nz,tile,share,block) for block in range(4) for family,nz in [('hydro',28),('bouss',129),('hydro',129),('bouss',28)]]
summary=[]
for family,nz,tile,share,block in cases:
 name=f'{family}-{nz}-t{tile}-s{share}-b{block}'
 args=[binary,'256','256',str(nz),family,str(tile),'12',str(samples),str(block%2),str(share)]
 start=time.time();r=subprocess.run(args,text=True,capture_output=True)
 (out/f'{name}.stderr').write_text(r.stderr)
 if r.returncode: raise RuntimeError((name,r.returncode,r.stderr))
 d=json.loads(r.stdout);d['command']=args;d['processStartUnix']=start;d['processEndUnix']=time.time()
 (out/f'{name}.json').write_text(json.dumps(d,indent=2)+'\n')
 ratios=[p['ratio'] for p in d['samples']]
 row={'name':name,'ratioMedian':statistics.median(ratios),'baselineMedian':statistics.median(p['baselineSeconds'] for p in d['samples']),'candidateMedian':statistics.median(p['candidateSeconds'] for p in d['samples']),'scratchMiB':[d['baselineAdditionalScratchBytes']/2**20,d['candidateAdditionalScratchBytes']/2**20]}
 summary.append(row);print(json.dumps(row),flush=True)
 (out/'summary.json').write_text(json.dumps(summary,indent=2)+'\n')

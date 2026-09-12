import subprocess,json,pathlib,sys
binary=sys.argv[1];out=pathlib.Path(sys.argv[2]);out.mkdir(exist_ok=False)
cases=[(8,10,3,'hydro',2,12,1),(10,12,17,'bouss',4,3,0),(16,12,35,'bouss',16,3,1),(16,12,35,'hydro',16,3,0),(8,10,1,'hydro',1,1,0),(8,10,1,'bouss',4,12,1),(9,11,5,'bouss',4,3,1),(9,11,5,'hydro',2,3,0)]
for i,c in enumerate(cases):
 result=subprocess.run([binary,*map(str,c[:6]),'1','0',str(c[6])],capture_output=True,text=True)
 (out/f'{i}.stderr').write_text(result.stderr);assert result.returncode==0,(c,result.stderr)
 d=json.loads(result.stdout);assert d['verification']['passed'] and d['postflight']['passed'];(out/f'{i}.json').write_text(json.dumps(d,indent=2)+'\n')
print('Passed',len(cases),'oracle/partition/tail cases')

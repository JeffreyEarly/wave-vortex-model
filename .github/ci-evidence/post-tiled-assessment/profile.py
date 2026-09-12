import pathlib,json,hashlib,subprocess,time,shutil,sys,datetime
import netCDF4
root=pathlib.Path('/Users/jearly/Documents/OceanKitRepositories/wvm-v4-tiled-advection')
archive=pathlib.Path(__file__).resolve().parent
qualified=archive.parent
binary=qualified/'qualified-candidate-wave-vortex-run'
protocol=json.loads((qualified/'qualification/protocol.json').read_text())
def digest(p):return hashlib.sha256(pathlib.Path(p).read_bytes()).hexdigest()
assert digest(binary)==protocol['frozenSHA256'][str(binary)]
for p,h in protocol['candidateSourceSHA256'].items():
 if pathlib.Path(p).suffix in {'.cpp','.hpp','.h','.c','.cmake'} or pathlib.Path(p).name=='CMakeLists.txt': assert digest(root/p)==h,p
for p,h in json.loads((qualified/'frozen-build.json').read_text())['filesSHA256'].items(): assert digest(p)==h,p
idx=int(sys.argv[1]);p=json.loads((qualified/'qualification-manifest.json').read_text())['profiles'][idx]
name=p['id']+'-'+sys.argv[2];d=archive/name;d.mkdir(exist_ok=False)
assert digest(p['sourcePath'])==p['sourceSHA256'];shutil.copyfile(p['sourcePath'],d/'output.nc')
req=p['request'];req['execution']['variableEvaluationPolicy']='reuse'
end={0:103716000,2:40,3:163}[idx];delay={0:3,2:10,3:45}[idx]
req['integration']['finalTime']=end
with netCDF4.Dataset(d/'output.nc','r+') as nc:
 g=nc.groups['wave-vortex'];g.variables['outputInterval'].assignValue({0:36000,2:40,3:80}[idx]);g.variables['finalTime'].assignValue(end)
req['modelFiles']=[str(d/'output.nc')];req['report']=str(d/'report.json');(d/'request.json').write_text(json.dumps(req,indent=2)+'\n')
meta={'kind':'exploratory sampling; not wall-time or speedup qualification','frozenCandidateCommit':protocol['candidateSourceCommit'],'binary':str(binary),'binarySHA256':digest(binary),'originalFixture':p['sourcePath'],'originalFixtureSHA256':p['sourceSHA256'],'preparedFixtureSHA256':digest(d/'output.nc'),'startedUTC':datetime.datetime.now(datetime.timezone.utc).isoformat(),'sampleDelaySeconds':delay,'sampleSeconds':20,'sampleIntervalMilliseconds':1,'adjustments':'Extended continuation and endpoint primary output on disposable copy. Existing other observer schedules retained.','backgroundActivityBefore':subprocess.check_output(['ps','-Ao','pid,pcpu,comm'],text=True)}
(d/'protocol.json').write_text(json.dumps(meta,indent=2)+'\n')
with open(d/'stdout.log','w') as out,open(d/'stderr.log','w') as err:
 proc=subprocess.Popen([str(binary),'--request',str(d/'request.json')],stdout=out,stderr=err)
 print(name,'pid',proc.pid,flush=True);time.sleep(delay)
 result=subprocess.run(['/usr/bin/sample',str(proc.pid),'20','1','-file',str(d/'sample.txt')],capture_output=True,text=True)
 (d/'sample-command.log').write_text(result.stdout+result.stderr)
 code=proc.wait(timeout=300)
assert code==0,(name,code)
r=json.loads((d/'report.json').read_text());assert r['status']=='complete'
assert r['source']['commit']==protocol['candidateSourceCommit']
assert r['variableEvaluation']['kernelProducers']['tiledNonlinearExecutions']>0
assert r['variableEvaluation']['rightHandSide']['duplicateExecutions']==0
assert digest(p['sourcePath'])==p['sourceSHA256'] and digest(binary)==protocol['frozenSHA256'][str(binary)]
meta.update(finishedUTC=datetime.datetime.now(datetime.timezone.utc).isoformat(),sampleExitCode=result.returncode,reportSHA256=digest(d/'report.json'),sampleSHA256=digest(d/'sample.txt'),backgroundActivityAfter=subprocess.check_output(['ps','-Ao','pid,pcpu,comm'],text=True))
(d/'protocol.json').write_text(json.dumps(meta,indent=2)+'\n')
print(name,'completed',r['timingSeconds'],flush=True)

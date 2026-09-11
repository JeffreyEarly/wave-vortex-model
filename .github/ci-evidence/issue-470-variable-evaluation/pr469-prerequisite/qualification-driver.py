#!/usr/bin/env python3
"""Matched old-path regression check. Reuses #455 comparator and wait4 helper."""
import importlib.util,json,pathlib,shutil,subprocess,statistics,hashlib,sys,math
ROOT=pathlib.Path('/Users/jearly/Documents/OceanKitRepositories/wvm-v4-issue454-sampling')
OUT=pathlib.Path(__file__).resolve().parent/'campaign'
spec=importlib.util.spec_from_file_location('model',ROOT/'Benchmarks/constant-adoption/run_model_adoption.py'); helper=importlib.util.module_from_spec(spec);spec.loader.exec_module(helper)
BASE=pathlib.Path('/private/tmp/wvm455-runner-final-default-build/wave-vortex-run')
NEW=pathlib.Path('/private/tmp/wvm454-sampling-native-release/wave-vortex-run')
assert len(sys.argv)==2,'Pass frozen candidate binary SHA256 from final build receipt'
assert helper.digest(NEW)==sys.argv[1]
inputs=[pathlib.Path(__file__),ROOT/'Benchmarks/constant-adoption/run_model_adoption.py']
assert helper.digest(BASE)=='7b301e5eef65afc18386596243f13f9dc0a9b719a25c45032bed2d49d1cf62b5'
assert subprocess.check_output(['git','diff','b71860fc4cc877298abf5dbb39a3716acc5f0cf4','a74ed4e6','--','PortableRuntime/include','PortableRuntime/src','PortableRuntime/app','PortableRuntime/CMakeLists.txt','CompiledKernel/include','CompiledKernel/src','CompiledKernel/CMakeLists.txt'],cwd=ROOT)==b''
profiles=[]
for path,identity in [('/private/tmp/wvm455-large-model-fixtures/manifest.json','constant-nonhydrostatic-composite-256'),('/private/tmp/wvm455-variable-model-large/manifest.json','variable-hydrostatic-composite-large')]:
 inputs.append(pathlib.Path(path))
 manifest=json.loads(pathlib.Path(path).read_text());profile=next(p for p in manifest['profiles'] if p['id']==identity)
 for kind in ['source','reference']:
  inputs.append(pathlib.Path(profile[kind+'Path']));assert helper.digest(profile[kind+'Path'])==profile[kind+'SHA256']
 if 'requestPath' in profile:
  inputs.append(pathlib.Path(profile['requestPath']));assert helper.digest(profile['requestPath'])==profile['requestSHA256']
 profile['manifestPath']=path;profile['manifestSHA256']=helper.digest(path)
 profile['steps']=4 if identity.startswith('constant') else 1
 profile['request']=json.loads(pathlib.Path(profile['requestPath']).read_text()) if 'requestPath' in profile else {'schemaIdentifier':'wave-vortex-run-request-v2','schemaVersion':2,'integration':{'method':'fixed-rk4','finalTime':0.5,'initialStep':0.5},'output':{'policy':'append','destinations':{}},'execution':{'fftProvider':'native-fftw','threads':1}}
 profiles.append(profile)
input_hashes={str(p):helper.digest(p) for p in inputs}
OUT.mkdir(exist_ok=False)
def on_error(kind,value,traceback):
 helper.save(OUT/'failure.json',{'status':'incomplete','exception':kind.__name__,'cause':str(value)})
 sys.__excepthook__(kind,value,traceback)
sys.excepthook=on_error
helper.save(OUT/'input-sha256.json',input_hashes)
source_paths=subprocess.check_output(['git','ls-files','PortableRuntime/include','PortableRuntime/src','PortableRuntime/app','PortableRuntime/CMakeLists.txt','CompiledKernel/include','CompiledKernel/src','CompiledKernel/CMakeLists.txt'],cwd=ROOT,text=True).splitlines()
source_hashes={p:helper.digest(ROOT/p) for p in source_paths}
helper.save(OUT/'candidate-source-sha256.json',source_hashes)
executables={'control':BASE,'candidate':NEW}; hashes={k:helper.digest(v) for k,v in executables.items()}
helper.save(OUT/'protocol.json',{'warmupPairs':2,'measuredPairs':8,'order':'alternating','comparison':'complete NetCDF graph control/candidate at existing MATLAB/native 1e-10/1e-12 tolerances, with exact metadata and integration controls; baseline self-repeat evidence documents native final-bit variability','timingGate':'each profile geometric integration ratio <=1.03; equal-profile paired-bootstrap upper95 <=1.03','memoryGate':'each profile max owned retained increase <=368 bytes derived fixed metadata allowance; no new scientific volume; peak RSS reported','profiles':profiles,'binaries':{k:{'path':str(v),'sha256':hashes[k]} for k,v in executables.items()},'driverSHA256':helper.digest(__file__),'helperSHA256':helper.digest(ROOT/'Benchmarks/constant-adoption/run_model_adoption.py')})
rows=[]
for p in profiles:
 for index in range(-2,8):
  pair={'profile':p['id'],'pair':index,'warmup':index<0,'runs':{}}
  for role in (['control','candidate'] if index%2==0 else ['candidate','control']):
   directory=OUT/(p['id']+f'-{index}-{role}');directory.mkdir();output=directory/'output.nc';request=directory/'request.json';report=directory/'report.json'
   assert helper.digest(executables[role])==hashes[role]
   shutil.copyfile(p['sourcePath'],output)
   req=dict(p['request']);req.update(modelFiles=[str(output)],report=str(report));helper.save(request,req)
   run=helper.run_child([str(executables[role]),'--request',str(request)],directory)
   assert run['exitCode']==0,(directory,run)
   result=json.loads(report.read_text());assert result['status']=='complete'
   assert result['provider']['id']=='native-fftw' and result['provider']['version']=='fftw-3.3.11-neon'
   assert result['state']['stepCount']==p['steps'] and result['state']['rhsEvaluationCount']==4*p['steps'] and result['state']['rejectedStepCount']==0
   assert result['densityEvaluation']['recoveryCount']==0 and result['diagnosticEvaluation']['evaluationCount']==0
   run.update(directory=str(directory),timingSeconds=result['timingSeconds'],storageBytes=result['storageBytes'],livenessBytes=result['livenessBytes'],state=result['state'],outputSHA256=helper.digest(output))
   pair['runs'][role]=run;helper.save(directory/'run.json',run)
   print(p['id'],index,role,'integrate',result['timingSeconds']['integrate'],flush=True)
  a,b=[pathlib.Path(pair['runs'][role]['directory'])/'output.nc' for role in ['control','candidate']]
  comparison=helper.compare_graph(a,b,1e-10,1e-12);comparison["bitwiseEqual"]=comparison["passed"] and all(v.get("maximumAbsoluteError",0)==0 for v in comparison["variables"]);helper.save(OUT/(p['id']+f'-{index}-comparison.json'),comparison);assert comparison['passed'],comparison['differences']
  if index==0:
   comparison=helper.compare_graph(p['referencePath'],b,1e-10,1e-12,history_policy='matlab-writer-provenance');helper.save(OUT/(p['id']+'-matlab-comparison.json'),comparison);assert comparison['passed'],comparison['differences']
  rows.append(pair);helper.save(OUT/'pairs.json',rows)
  if index!=0: a.unlink();b.unlink()
summary=[];logs=[]
for p in profiles:
 pairs=[r for r in rows if r['profile']==p['id'] and not r['warmup']]
 ratios=[r['runs']['candidate']['timingSeconds']['integrate']/r['runs']['control']['timingSeconds']['integrate'] for r in pairs];logs.append(helper.np.log(ratios))
 deltas=[r['runs']['candidate']['livenessBytes']['fullModelRetained']-r['runs']['control']['livenessBytes']['fullModelRetained'] for r in pairs]
 row={'profile':p['id'],'integrationRatio':math.exp(statistics.mean(map(math.log,ratios))),'ratios':ratios,'maximumRetainedDeltaBytes':max(deltas),'peakRSSRatio':math.exp(statistics.mean(math.log(r['runs']['candidate']['completeLifetimePeakRSSBytes']/r['runs']['control']['completeLifetimePeakRSSBytes']) for r in pairs))};summary.append(row)
rng=helper.np.random.default_rng(454);samples=sum(v[rng.integers(0,len(v),size=(10000,len(v)))].mean(axis=1)/len(logs) for v in logs);ci=helper.np.exp(helper.np.quantile(samples,[.025,.975])).tolist()
passed=all(r['integrationRatio']<=1.03 and r['maximumRetainedDeltaBytes']<=368 for r in summary) and ci[1]<=1.03
for k,v in executables.items(): assert helper.digest(v)==hashes[k]
assert source_hashes=={p:helper.digest(ROOT/p) for p in source_paths}
assert input_hashes=={str(p):helper.digest(p) for p in inputs}
helper.save(OUT/'summary.json',{'passed':passed,'profiles':summary,'equalProfileBootstrap95':ci,'allScientificComparisonsPassed':True,'measuredPairs':16,'warmupPairs':4,'postflightUnchanged':True})
for k,v in executables.items(): assert helper.digest(v)==hashes[k]
assert source_hashes=={p:helper.digest(ROOT/p) for p in source_paths}
assert input_hashes=={str(p):helper.digest(p) for p in inputs}
print(json.dumps({'passed':passed,'profiles':summary,'bootstrap95':ci}),flush=True)

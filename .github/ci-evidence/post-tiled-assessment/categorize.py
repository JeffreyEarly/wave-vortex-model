import pathlib,sys,json,collections
parser=pathlib.Path(__file__).with_name('summarize_samples.py').read_text().split('selfs=collections.Counter()')[0]
exec(parser)
counts={name:collections.Counter() for name in ['main','allActive','mainWaitByStage']}
incs=collections.Counter()
for n in nodes:
 if not n['self']:continue
 ancestors=[];x=n
 while x:
  ancestors.append(x['fn']);x=nodes[x['parent']] if x['parent'] is not None else None
 def has(s):return any(s in a for a in ancestors)
 def cat():
  if 'libfftw3' in n['label']: return 'FFT library'
  if 'libBLAS' in n['label']:return 'BLAS library'
  if has('verticalCalculus(') or has('advectScalarWithAdvectionFields(') or has('spatialDerivative('): return 'Tracer/scalar derivative arithmetic'
  if has('RetainedFFTWPlan::advectionTask'): return 'Tiled adapter/advection arithmetic'
  if has('WVAdvectionConsumer::consume'): return 'Advection pointwise arithmetic/control'
  if has('RetainedFFTWPlan::'): return 'FFT adapter movement/control'
  if has('WVPreparedVerticalOperator::execute') or has('executePreparedGroups('):return 'Matrix adapter/packing'
  if has('stateContents(') or has('validateState('):return 'State validation'
  if has('preparePhase('):return 'Phase preparation'
  if has('horizontalSpeedMaximum('):return 'Speed reduction'
  if has('projectedFieldsToCoefficients(') or has('projectSpectralFields('):return 'Projection pointwise arithmetic'
  if has('Kernel::reconstruct('):return 'Field assembly/derivative arithmetic'
  if has('Kernel::nonlinearFlux('):return 'Advection pointwise arithmetic/control'
  if has('addAdaptiveDamping('):return 'Damping pointwise arithmetic'
  if has('WVAdaptiveRK78::') or has('WVFixedRK4::'):return 'Integrator/state arithmetic/control'
  return 'Other runtime/control'
 stage=cat()
 wait=n['fn'] in ['__psynch_cvwait','__workq_kernreturn','semaphore_wait_trap','mach_msg2_trap','__ulock_wait','__ulock_wait2']
 if n['thread']==0:
  counts['main']['Wait' if wait else stage]+=n['self']
  if wait:counts['mainWaitByStage'][stage]+=n['self']
 if not wait:counts['allActive'][stage]+=n['self']
 if n['thread']==0:
  for key in ['Kernel::reconstruct(','HorizontalOperator::inverse','HorizontalOperator::forward(','WVPreparedVerticalOperator::execute','projectSpectralFields(','projectedFieldsToCoefficients(','preparePhase(','stateContents(','horizontalSpeedMaximum(','advectScalarWithAdvectionFields(','verticalCalculus(','Kernel::nonlinearFluxAndFields(','RetainedFFTWPlan::advectionTask','Kernel::nonlinearFlux(','WVAdaptiveRK78::stepImplementation(']:
   if has(key):incs[key]+=n['self']
result={key:{'totalSamples':sum(c.values()),'counts':dict(c),'percent':{k:round(100*v/sum(c.values()),2) for k,v in c.most_common()}} for key,c in counts.items()}
result['mainInclusive']={k:round(100*v/nodes[0]['count'],2) for k,v in incs.items()}
p.with_name('category-summary.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps(result,indent=2))
